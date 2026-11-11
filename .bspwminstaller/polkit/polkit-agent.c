/*
 * polkit-agent — polkit password dialog while bspwm runs.
 *
 * Under GNOME the polkit agent is gnome-shell, which bspwm.sh stops. An agent
 * inside junest (lxpolkit...) can't work: polkit-agent-helper-1 must be setuid
 * root and setuid does nothing in junest's user namespace. This one runs on the
 * HOST: bspwm.sh compiles it with Ubuntu's gcc, GTK 3 and libpolkit-agent-1
 * (whose helper is setuid root), starts it once gnome-shell is gone and stops it
 * before GNOME comes back.
 *
 * Python can't do it on Ubuntu 22.04: PyGObject 3.42 segfaults when polkitd
 * calls the initiate_authentication vfunc.
 *
 * Build: gcc -O2 -std=gnu11 polkit-agent.c -o polkit-agent \
 *            $(pkg-config --cflags --libs gtk+-3.0) -l:libpolkit-agent-1.so.0 -l:libpolkit-gobject-1.so.0
 */
#include <gtk/gtk.h>
#include <pwd.h>
#include <unistd.h>

/* Ubuntu has libpolkit-agent-1.so.0 but not its headers (libpolkit-agent-1-dev):
 * the few declarations used here, ABI-stable since polkit 0.9x. */
typedef struct _PolkitSubject PolkitSubject;
typedef struct _PolkitIdentity PolkitIdentity;
typedef struct _PolkitDetails PolkitDetails;
typedef struct _PolkitAgentSession PolkitAgentSession;
typedef struct { GObject parent_instance; } PolkitAgentListener;
typedef struct {
    GObjectClass parent_class;
    void (*initiate_authentication)(PolkitAgentListener *listener, const gchar *action_id,
                                    const gchar *message, const gchar *icon_name,
                                    PolkitDetails *details, const gchar *cookie, GList *identities,
                                    GCancellable *cancellable, GAsyncReadyCallback callback,
                                    gpointer user_data);
    gboolean (*initiate_authentication_finish)(PolkitAgentListener *listener, GAsyncResult *res,
                                               GError **error);
    void (*reserved[8])(void);
} PolkitAgentListenerClass;

GType polkit_agent_listener_get_type(void);
GType polkit_unix_user_get_type(void);
gint polkit_unix_user_get_uid(gpointer user);
gchar *polkit_identity_to_string(PolkitIdentity *identity);
PolkitSubject *polkit_unix_session_new_for_process_sync(gint pid, GCancellable *cancellable, GError **error);
gpointer polkit_agent_listener_register(PolkitAgentListener *listener, gint flags, PolkitSubject *subject,
                                       const gchar *object_path, GCancellable *cancellable, GError **error);
PolkitAgentSession *polkit_agent_session_new(PolkitIdentity *identity, const gchar *cookie);
void polkit_agent_session_initiate(PolkitAgentSession *session);
void polkit_agent_session_response(PolkitAgentSession *session, const gchar *response);
void polkit_agent_session_cancel(PolkitAgentSession *session);

/* ── One authentication request ─────────────────────────────────────────── */
typedef struct {
    GTask *task;
    GCancellable *cancellable;
    gulong cancel_id;
    gchar *cookie;
    GPtrArray *identities;        /* PolkitIdentity, referenced */
    PolkitAgentSession *session;
    GtkWidget *dialog, *combo, *prompt, *entry, *info;
    gboolean done;
} Auth;

static gchar *identity_name(PolkitIdentity *id)
{
    if (G_TYPE_CHECK_INSTANCE_TYPE(id, polkit_unix_user_get_type())) {
        struct passwd *pw = getpwuid((uid_t)polkit_unix_user_get_uid(id));
        if (pw)
            return g_strdup(pw->pw_name);
    }
    return polkit_identity_to_string(id);
}

static guint default_identity(Auth *a)
{
    for (guint i = 0; i < a->identities->len; i++) {
        PolkitIdentity *id = g_ptr_array_index(a->identities, i);
        if (G_TYPE_CHECK_INSTANCE_TYPE(id, polkit_unix_user_get_type()) &&
            polkit_unix_user_get_uid(id) == (gint)getuid())
            return i;
    }
    return 0;
}

static PolkitIdentity *selected_identity(Auth *a)
{
    gint i = a->combo ? gtk_combo_box_get_active(GTK_COMBO_BOX(a->combo)) : (gint)default_identity(a);
    return g_ptr_array_index(a->identities, i < 0 ? 0 : (guint)i);
}

static void show_info(Auth *a, const gchar *text, gboolean error)
{
    gchar *m = error ? g_markup_printf_escaped("<span foreground='#e06c75'>%s</span>", text)
                     : g_markup_escape_text(text, -1);
    gtk_label_set_markup(GTK_LABEL(a->info), m);
    gtk_widget_show(a->info);
    g_free(m);
}

static void drop_session(Auth *a)
{
    if (!a->session)
        return;
    g_signal_handlers_disconnect_by_data(a->session, a);
    polkit_agent_session_cancel(a->session);
    g_object_unref(a->session);
    a->session = NULL;
}

static void finish(Auth *a, gboolean ok)
{
    if (a->done)
        return;
    a->done = TRUE;
    drop_session(a);
    if (a->cancellable && a->cancel_id)
        g_cancellable_disconnect(a->cancellable, a->cancel_id);
    gtk_widget_destroy(a->dialog);
    if (ok)
        g_task_return_boolean(a->task, TRUE);
    else
        g_task_return_new_error(a->task, G_IO_ERROR, G_IO_ERROR_CANCELLED, "Authentication dialog was dismissed");
    g_object_unref(a->task);
    g_ptr_array_unref(a->identities);
    g_free(a->cookie);
    g_free(a);
}

static void start_session(Auth *a);

static void on_request(PolkitAgentSession *s, const gchar *request, gboolean echo_on, Auth *a)
{
    (void)s;
    gchar *r = g_strstrip(g_strdup(request));
    gtk_label_set_text(GTK_LABEL(a->prompt), *r ? r : "Password:");
    g_free(r);
    gtk_entry_set_visibility(GTK_ENTRY(a->entry), echo_on);
    gtk_widget_set_sensitive(a->entry, TRUE);
    gtk_window_present(GTK_WINDOW(a->dialog));
    gtk_widget_grab_focus(a->entry);
}

static gboolean restart_session(gpointer data)
{
    Auth *a = data;
    if (!a->done)
        start_session(a);
    return G_SOURCE_REMOVE;
}

static void on_completed(PolkitAgentSession *s, gboolean gained, Auth *a)
{
    (void)s;
    if (gained) {
        finish(a, TRUE);
        return;
    }
    /* Wrong password: a new session asks again (not from inside its own signal) */
    show_info(a, "Authentication failed, try again.", TRUE);
    gtk_entry_set_text(GTK_ENTRY(a->entry), "");
    g_idle_add(restart_session, a);
}

static void on_show_error(PolkitAgentSession *s, const gchar *text, Auth *a) { (void)s; show_info(a, text, TRUE); }
static void on_show_info(PolkitAgentSession *s, const gchar *text, Auth *a) { (void)s; show_info(a, text, FALSE); }

static void start_session(Auth *a)
{
    drop_session(a);
    a->session = polkit_agent_session_new(selected_identity(a), a->cookie);
    g_signal_connect(a->session, "request", G_CALLBACK(on_request), a);
    g_signal_connect(a->session, "completed", G_CALLBACK(on_completed), a);
    g_signal_connect(a->session, "show-error", G_CALLBACK(on_show_error), a);
    g_signal_connect(a->session, "show-info", G_CALLBACK(on_show_info), a);
    polkit_agent_session_initiate(a->session);
}

static void on_response(GtkDialog *d, gint response, Auth *a)
{
    (void)d;
    if (response == GTK_RESPONSE_OK) {
        gtk_widget_set_sensitive(a->entry, FALSE);
        if (a->session)
            polkit_agent_session_response(a->session, gtk_entry_get_text(GTK_ENTRY(a->entry)));
    } else {
        finish(a, FALSE);
    }
}

static gboolean cancel_idle(gpointer data)
{
    finish(data, FALSE);
    return G_SOURCE_REMOVE;
}

static void on_cancelled(GCancellable *c, Auth *a)
{
    (void)c;
    g_idle_add(cancel_idle, a);
}

static void build_dialog(Auth *a, const gchar *message, const gchar *icon_name)
{
    a->dialog = gtk_dialog_new_with_buttons("Authentication required", NULL, 0,
                                            "Cancel", GTK_RESPONSE_CANCEL,
                                            "Authenticate", GTK_RESPONSE_OK, NULL);
    GtkWindow *w = GTK_WINDOW(a->dialog);
    gtk_window_set_keep_above(w, TRUE);
    gtk_window_set_position(w, GTK_WIN_POS_CENTER);
    gtk_window_set_resizable(w, FALSE);
    gtk_window_set_default_size(w, 420, -1);
    gtk_dialog_set_default_response(GTK_DIALOG(a->dialog), GTK_RESPONSE_OK);
    GtkWidget *ok = gtk_dialog_get_widget_for_response(GTK_DIALOG(a->dialog), GTK_RESPONSE_OK);
    gtk_style_context_add_class(gtk_widget_get_style_context(ok), "suggested-action");

    GtkWidget *box = gtk_dialog_get_content_area(GTK_DIALOG(a->dialog));
    gtk_box_set_spacing(GTK_BOX(box), 10);
    gtk_container_set_border_width(GTK_CONTAINER(box), 16);

    GtkWidget *top = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
    gtk_box_pack_start(GTK_BOX(top), gtk_image_new_from_icon_name(
        icon_name && *icon_name ? icon_name : "dialog-password", GTK_ICON_SIZE_DIALOG), FALSE, FALSE, 0);
    GtkWidget *msg = gtk_label_new(message);
    gtk_label_set_xalign(GTK_LABEL(msg), 0);
    gtk_label_set_line_wrap(GTK_LABEL(msg), TRUE);
    gtk_label_set_max_width_chars(GTK_LABEL(msg), 50);
    gtk_box_pack_start(GTK_BOX(top), msg, TRUE, TRUE, 0);
    gtk_box_pack_start(GTK_BOX(box), top, FALSE, FALSE, 0);

    if (a->identities->len > 1) {
        GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
        a->combo = gtk_combo_box_text_new();
        for (guint i = 0; i < a->identities->len; i++) {
            gchar *n = identity_name(g_ptr_array_index(a->identities, i));
            gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(a->combo), n);
            g_free(n);
        }
        gtk_combo_box_set_active(GTK_COMBO_BOX(a->combo), (gint)default_identity(a));
        gtk_box_pack_start(GTK_BOX(row), gtk_label_new("User:"), FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(row), a->combo, TRUE, TRUE, 0);
        gtk_box_pack_start(GTK_BOX(box), row, FALSE, FALSE, 0);
    } else if (a->identities->len == 1) {
        gchar *n = identity_name(g_ptr_array_index(a->identities, 0));
        gchar *t = g_strdup_printf("User: %s", n);
        GtkWidget *l = gtk_label_new(t);
        gtk_label_set_xalign(GTK_LABEL(l), 0);
        gtk_box_pack_start(GTK_BOX(box), l, FALSE, FALSE, 0);
        g_free(t);
        g_free(n);
    }

    a->prompt = gtk_label_new("Password:");
    gtk_label_set_xalign(GTK_LABEL(a->prompt), 0);
    gtk_box_pack_start(GTK_BOX(box), a->prompt, FALSE, FALSE, 0);
    a->entry = gtk_entry_new();
    gtk_entry_set_visibility(GTK_ENTRY(a->entry), FALSE);
    gtk_entry_set_activates_default(GTK_ENTRY(a->entry), TRUE);
    gtk_box_pack_start(GTK_BOX(box), a->entry, FALSE, FALSE, 0);
    a->info = gtk_label_new("");
    gtk_label_set_xalign(GTK_LABEL(a->info), 0);
    gtk_label_set_line_wrap(GTK_LABEL(a->info), TRUE);
    gtk_widget_set_no_show_all(a->info, TRUE);
    gtk_box_pack_start(GTK_BOX(box), a->info, FALSE, FALSE, 0);

    g_signal_connect(a->dialog, "response", G_CALLBACK(on_response), a);
    gtk_widget_show_all(a->dialog);
}

/* ── The listener ───────────────────────────────────────────────────────── */
typedef PolkitAgentListener BspwmAgent;
typedef PolkitAgentListenerClass BspwmAgentClass;
G_DEFINE_TYPE(BspwmAgent, bspwm_agent, polkit_agent_listener_get_type())

static void initiate(PolkitAgentListener *listener, const gchar *action_id, const gchar *message,
                     const gchar *icon_name, PolkitDetails *details, const gchar *cookie,
                     GList *identities, GCancellable *cancellable, GAsyncReadyCallback callback,
                     gpointer user_data)
{
    (void)action_id;
    (void)details;
    Auth *a = g_new0(Auth, 1);
    a->task = g_task_new(listener, cancellable, callback, user_data);
    a->cookie = g_strdup(cookie);
    a->identities = g_ptr_array_new_with_free_func(g_object_unref);
    for (GList *l = identities; l; l = l->next)
        g_ptr_array_add(a->identities, g_object_ref(l->data));
    if (a->identities->len == 0) {
        g_task_return_new_error(a->task, G_IO_ERROR, G_IO_ERROR_FAILED, "No identity to authenticate as");
        g_object_unref(a->task);
        g_ptr_array_unref(a->identities);
        g_free(a->cookie);
        g_free(a);
        return;
    }
    build_dialog(a, message, icon_name);
    if (cancellable) {
        a->cancellable = cancellable;
        a->cancel_id = g_cancellable_connect(cancellable, G_CALLBACK(on_cancelled), a, NULL);
    }
    if (a->combo)
        g_signal_connect_swapped(a->combo, "changed", G_CALLBACK(start_session), a);
    start_session(a);
    gtk_window_present(GTK_WINDOW(a->dialog));
}

static gboolean initiate_finish(PolkitAgentListener *listener, GAsyncResult *res, GError **error)
{
    (void)listener;
    return g_task_propagate_boolean(G_TASK(res), error);
}

static void bspwm_agent_init(BspwmAgent *self) { (void)self; }

static void bspwm_agent_class_init(BspwmAgentClass *klass)
{
    klass->initiate_authentication = initiate;
    klass->initiate_authentication_finish = initiate_finish;
}

int main(int argc, char **argv)
{
    gtk_init(&argc, &argv);
    GError *err = NULL;
    PolkitSubject *subject = polkit_unix_session_new_for_process_sync(getpid(), NULL, &err);
    if (!subject) {
        g_printerr("polkit-agent: no login session: %s\n", err ? err->message : "?");
        return 1;
    }
    PolkitAgentListener *agent = g_object_new(bspwm_agent_get_type(), NULL);
    /* gnome-shell (just killed by bspwm.sh) may not have released its registration yet */
    gpointer handle = NULL;
    for (int attempt = 0; attempt < 15 && !handle; attempt++) {
        g_clear_error(&err);
        handle = polkit_agent_listener_register(agent, 0, subject, "/org/bspwm/PolicyKit1/AuthenticationAgent",
                                                NULL, &err);
        if (!handle)
            g_usleep(2 * G_USEC_PER_SEC);
    }
    if (!handle) {
        g_printerr("polkit-agent: could not register: %s\n", err ? err->message : "?");
        return 1;
    }
    g_printerr("polkit-agent: registered\n");
    gtk_main();
    return 0;
}
