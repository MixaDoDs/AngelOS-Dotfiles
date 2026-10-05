/* angelOS minimize hook — LD_PRELOAD for every app of the session (build.sh, install.sh).

   niri has no minimizing: a window's own minimize button (GTK 3/4's yellow light, Qt's, Firefox's)
   sends xdg_toplevel.set_minimized and niri ignores it. Every toolkit sends that request through
   libwayland-client's wl_proxy_marshal_flags (wl_proxy_marshal for old wayland-scanner code), a
   call between libraries, so a preloaded library sees it even in GTK 4 (built -Bsymbolic: its own
   gtk_window_minimize can't be interposed). This one passes everything on exactly as libwayland
   does (signature → wl_argument[] → wl_proxy_marshal_array_flags), except set_minimized: that one
   goes to angelOS — a line "<pid>\t<title>\n" to $XDG_RUNTIME_DIR/angelos-minimize.sock, where
   services/Minimize.qml listens while the Golden Gate skin is on and minimizes the window its own
   way. Nobody listening (another skin, the shell down): the request goes to the compositor as
   before. The window's title (set_title, kept per toplevel) tells apart the windows of one process
   (Nautilus has one for all of them). Apps that bring their own libwayland (Chromium, Electron)
   don't pass here.
   GTK 4 asks first: it minimizes only when the compositor lists "minimize" in
   xdg_toplevel.wm_capabilities (else gdk_toplevel_minimize drops it, the button does nothing), and
   niri never sends that event (an empty set isn't sent). So while angelOS listens (the socket is
   there) the listener of each toplevel is wrapped (wl_proxy_add_listener): with every configure
   it gets a wm_capabilities of its own — "minimize" — as a compositor would send it, and a real
   wm_capabilities gets "minimize" added. ANGELOS_MINIMIZE_DEBUG=1 prints the xdg_* requests. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

struct wl_proxy;
struct wl_interface;
struct wl_message {
    const char *name;
    const char *signature;
    const struct wl_interface **types;
};
struct wl_interface {
    const char *name;
    int version;
    int method_count;
    const struct wl_message *methods;
    int event_count;
    const struct wl_message *events;
};
union wl_argument {
    int32_t i;
    uint32_t u;
    int32_t f;
    const char *s;
    void *o;
    uint32_t n;
    void *a;
    int32_t h;
};

#define MAX_ARGS 20                 /* WL_CLOSURE_MAX_ARGS */
#define XDG_TOPLEVEL_DESTROY 0
#define XDG_TOPLEVEL_SET_TITLE 2
#define XDG_TOPLEVEL_SET_MINIMIZED 13
#define XDG_TOPLEVEL_EVENT_WM_CAPABILITIES 3   /* since version 5 */
#define XDG_TOPLEVEL_WM_CAPABILITIES_MINIMIZE 4

struct wl_array {
    size_t size;
    size_t alloc;
    void *data;
};

typedef const struct wl_interface *(*get_interface_fn)(struct wl_proxy *);
typedef struct wl_proxy *(*marshal_array_flags_fn)(struct wl_proxy *, uint32_t, const struct wl_interface *, uint32_t, uint32_t, union wl_argument *);
typedef void (*marshal_array_fn)(struct wl_proxy *, uint32_t, union wl_argument *);
typedef int (*add_listener_fn)(struct wl_proxy *, void (**)(void), void *);
typedef uint32_t (*get_version_fn)(struct wl_proxy *);
typedef void (*caps_fn)(void *, struct wl_proxy *, struct wl_array *);
typedef void (*configure_fn)(void *, struct wl_proxy *, int32_t, int32_t, struct wl_array *);

static get_interface_fn get_interface;
static marshal_array_flags_fn marshal_array_flags;
static marshal_array_fn marshal_array;
static add_listener_fn add_listener;
static get_version_fn get_version;

/* the real functions: the next definition after this library (the system libwayland, linked in);
   failing that the libwayland-client already loaded into the process — kitty's GLFW dlopens its
   own copy (RTLD_LOCAL), which RTLD_NEXT doesn't see; without it every request went nowhere and
   kitty found no xdg-shell. Never a library of our own: a second libwayland can't take these proxies. */
static void *find(const char *name) {
    void *f = dlsym(RTLD_NEXT, name);
    if (f)
        return f;
    void *h = dlopen("libwayland-client.so.0", RTLD_LAZY | RTLD_NOLOAD);
    if (!h)
        return NULL;
    f = dlsym(h, name);
    dlclose(h);
    return f;
}

static void resolve(void) {
    if (!get_interface)
        get_interface = (get_interface_fn)find("wl_proxy_get_interface");
    if (!marshal_array_flags)
        marshal_array_flags = (marshal_array_flags_fn)find("wl_proxy_marshal_array_flags");
    if (!marshal_array)
        marshal_array = (marshal_array_fn)find("wl_proxy_marshal_array");
    if (!add_listener)
        add_listener = (add_listener_fn)find("wl_proxy_add_listener");
    if (!get_version)
        get_version = (get_version_fn)find("wl_proxy_get_version");
}

/* libwayland's wl_argument_from_va_list: one argument per type letter, digits (since-version)
   and '?' (nullable) skipped */
static void args_from_va(const char *sig, union wl_argument *args, va_list ap) {
    int i = 0;
    for (const char *p = sig; p && *p && i < MAX_ARGS; p++) {
        switch (*p) {
        case 'i': args[i++].i = va_arg(ap, int32_t); break;
        case 'u': args[i++].u = va_arg(ap, uint32_t); break;
        case 'f': args[i++].f = va_arg(ap, int32_t); break;
        case 's': args[i++].s = va_arg(ap, const char *); break;
        case 'o': args[i++].o = va_arg(ap, void *); break;
        case 'n': args[i++].o = va_arg(ap, void *); break;
        case 'a': args[i++].a = va_arg(ap, void *); break;
        case 'h': args[i++].h = va_arg(ap, int32_t); break;
        default: break;
        }
    }
}

/* ---- the toplevels' titles ---- */
#define SLOTS 128
static struct {
    struct wl_proxy *proxy;
    char title[256];
} titles[SLOTS];
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

static void remember(struct wl_proxy *proxy, const char *title) {
    pthread_mutex_lock(&lock);
    int free_slot = -1;
    for (int i = 0; i < SLOTS; i++) {
        if (titles[i].proxy == proxy) {
            free_slot = i;
            break;
        }
        if (free_slot < 0 && !titles[i].proxy)
            free_slot = i;
    }
    if (free_slot < 0)
        free_slot = (int)((uintptr_t)proxy % SLOTS);
    titles[free_slot].proxy = title ? proxy : NULL;
    snprintf(titles[free_slot].title, sizeof titles[free_slot].title, "%s", title ? title : "");
    pthread_mutex_unlock(&lock);
}

static void title_of(struct wl_proxy *proxy, char *out, size_t n) {
    out[0] = 0;
    pthread_mutex_lock(&lock);
    for (int i = 0; i < SLOTS; i++)
        if (titles[i].proxy == proxy) {
            snprintf(out, n, "%s", titles[i].title);
            break;
        }
    pthread_mutex_unlock(&lock);
}

static int debug_on(void) {
    static int debug = -1;
    if (debug < 0)
        debug = getenv("ANGELOS_MINIMIZE_DEBUG") != NULL;
    return debug;
}

/* ---- angelOS's socket ---- */
static int socket_path(struct sockaddr_un *addr) {
    const char *rt = getenv("XDG_RUNTIME_DIR");
    if (!rt || !*rt)
        return 0;
    memset(addr, 0, sizeof *addr);
    addr->sun_family = AF_UNIX;
    return snprintf(addr->sun_path, sizeof addr->sun_path, "%s/angelos-minimize.sock", rt) < (int)sizeof addr->sun_path;
}
static int angelos_listens(void) {
    struct sockaddr_un addr;
    return socket_path(&addr) && access(addr.sun_path, F_OK) == 0;
}

/* ---- the toplevels' own listeners, wrapped for wm_capabilities ---- */
static struct {
    struct wl_proxy *proxy;
    caps_fn original;
    configure_fn configure;
    int real_caps;                  /* the compositor sent its own wm_capabilities */
    void (**table)(void);
} wrapped[SLOTS];

static int find_wrapped(struct wl_proxy *proxy) {
    for (int i = 0; i < SLOTS; i++)
        if (wrapped[i].proxy == proxy)
            return i;
    return -1;
}
static caps_fn original_caps(struct wl_proxy *proxy) {
    caps_fn f = NULL;
    pthread_mutex_lock(&lock);
    int i = find_wrapped(proxy);
    if (i >= 0)
        f = wrapped[i].original;
    pthread_mutex_unlock(&lock);
    return f;
}
static void forget_wrapped(struct wl_proxy *proxy) {
    pthread_mutex_lock(&lock);
    for (int i = 0; i < SLOTS; i++)
        if (wrapped[i].proxy == proxy) {
            free(wrapped[i].table);
            wrapped[i].proxy = NULL;
            wrapped[i].table = NULL;
        }
    pthread_mutex_unlock(&lock);
}

static void caps_wrapper(void *data, struct wl_proxy *toplevel, struct wl_array *caps) {
    pthread_mutex_lock(&lock);
    int slot = find_wrapped(toplevel);
    if (slot >= 0)
        wrapped[slot].real_caps = 1;
    pthread_mutex_unlock(&lock);
    caps_fn orig = original_caps(toplevel);
    if (debug_on()) {
        fprintf(stderr, "angelos-minimize: wm_capabilities");
        for (size_t i = 0; caps && i + 4 <= caps->size; i += 4)
            fprintf(stderr, " %u", ((uint32_t *)caps->data)[i / 4]);
        fprintf(stderr, " (listening %d)\n", angelos_listens());
    }
    if (!orig)
        return;
    int have = 0;
    for (size_t i = 0; caps && i + sizeof(uint32_t) <= caps->size; i += sizeof(uint32_t))
        if (((uint32_t *)caps->data)[i / sizeof(uint32_t)] == XDG_TOPLEVEL_WM_CAPABILITIES_MINIMIZE)
            have = 1;
    if (have || !angelos_listens()) {
        orig(data, toplevel, caps);
        return;
    }
    size_t n = caps ? caps->size : 0;
    uint32_t *buf = malloc(n + sizeof(uint32_t));
    if (!buf) {
        orig(data, toplevel, caps);
        return;
    }
    if (n)
        memcpy(buf, caps->data, n);
    buf[n / sizeof(uint32_t)] = XDG_TOPLEVEL_WM_CAPABILITIES_MINIMIZE;
    struct wl_array more = {.size = n + sizeof(uint32_t), .alloc = n + sizeof(uint32_t), .data = buf};
    orig(data, toplevel, &more);
    free(buf);
}

/* a configure from niri: the toplevel's own handler, then "minimize" as its wm_capabilities
   (before xdg_surface.configure commits the state, where a compositor's event would come) */
static void configure_wrapper(void *data, struct wl_proxy *toplevel, int32_t w, int32_t h, struct wl_array *states) {
    configure_fn conf = NULL;
    caps_fn caps = NULL;
    int real = 0;
    pthread_mutex_lock(&lock);
    int i = find_wrapped(toplevel);
    if (i >= 0) {
        conf = wrapped[i].configure;
        caps = wrapped[i].original;
        real = wrapped[i].real_caps;
    }
    pthread_mutex_unlock(&lock);
    if (conf)
        conf(data, toplevel, w, h, states);
    if (caps && !real && angelos_listens()) {
        uint32_t minimize = XDG_TOPLEVEL_WM_CAPABILITIES_MINIMIZE;
        struct wl_array one = {.size = sizeof minimize, .alloc = sizeof minimize, .data = &minimize};
        caps(data, toplevel, &one);
    }
}

int wl_proxy_add_listener(struct wl_proxy *proxy, void (**implementation)(void), void *data) {
    resolve();
    if (!add_listener)
        return -1;
    const struct wl_interface *iface = get_interface ? get_interface(proxy) : NULL;
    if (debug_on())
        fprintf(stderr, "angelos-minimize: add_listener %s v%u events %d\n", iface && iface->name ? iface->name : "?", get_version ? get_version(proxy) : 0, iface ? iface->event_count : -1);
    /* the interface is the app's own (generated with its listener struct): event_count is that
       struct's length; wm_capabilities comes only to toplevels bound at version 5 or later */
    if (!iface || !iface->name || strcmp(iface->name, "xdg_toplevel") != 0 || iface->event_count <= XDG_TOPLEVEL_EVENT_WM_CAPABILITIES || !get_version || get_version(proxy) < 5 || !implementation[XDG_TOPLEVEL_EVENT_WM_CAPABILITIES])
        return add_listener(proxy, implementation, data);
    void (**table)(void) = calloc((size_t)iface->event_count, sizeof *table);
    if (!table)
        return add_listener(proxy, implementation, data);
    memcpy(table, implementation, sizeof *table * (size_t)iface->event_count);
    int slot = -1;
    pthread_mutex_lock(&lock);
    for (int i = 0; i < SLOTS && slot < 0; i++)
        if (!wrapped[i].proxy)
            slot = i;
    if (slot >= 0) {
        wrapped[slot].proxy = proxy;
        wrapped[slot].original = (caps_fn)implementation[XDG_TOPLEVEL_EVENT_WM_CAPABILITIES];
        wrapped[slot].configure = (configure_fn)implementation[0];
        wrapped[slot].real_caps = 0;
        wrapped[slot].table = table;
    }
    pthread_mutex_unlock(&lock);
    if (slot < 0) {
        free(table);
        return add_listener(proxy, implementation, data);
    }
    table[XDG_TOPLEVEL_EVENT_WM_CAPABILITIES] = (void (*)(void))caps_wrapper;
    if (table[0])
        table[0] = (void (*)(void))configure_wrapper;
    return add_listener(proxy, table, data);
}

/* ---- the request to angelOS: 1 when it took it ---- */
static int tell_angelos(struct wl_proxy *proxy) {
    struct sockaddr_un addr;
    if (!socket_path(&addr))
        return 0;
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd < 0)
        return 0;
    if (connect(fd, (struct sockaddr *)&addr, sizeof addr) != 0) {
        close(fd);
        return 0;
    }
    char title[256], line[400];
    title_of(proxy, title, sizeof title);
    for (char *c = title; *c; c++)
        if (*c == '\t' || *c == '\n' || *c == '\r')
            *c = ' ';
    int len = snprintf(line, sizeof line, "%d\t%s\n", (int)getpid(), title);
    int ok = len > 0 && send(fd, line, (size_t)len, MSG_NOSIGNAL) == len;
    close(fd);
    return ok;
}

/* what to do with a request: 1 = swallowed (set_minimized taken by angelOS) */
static int look(struct wl_proxy *proxy, uint32_t opcode, union wl_argument *args) {
    if (!get_interface)
        return 0;
    const struct wl_interface *iface = get_interface(proxy);
    if (debug_on() && iface && iface->name && strncmp(iface->name, "xdg_", 4) == 0)
        fprintf(stderr, "angelos-minimize: %s.%s\n", iface->name, (int)opcode < iface->method_count ? iface->methods[opcode].name : "?");
    if (!iface || !iface->name || strcmp(iface->name, "xdg_toplevel") != 0)
        return 0;
    if (opcode == XDG_TOPLEVEL_SET_TITLE)
        remember(proxy, args[0].s);
    else if (opcode == XDG_TOPLEVEL_DESTROY) {
        remember(proxy, NULL);
        forget_wrapped(proxy);
    }
    else if (opcode == XDG_TOPLEVEL_SET_MINIMIZED)
        return tell_angelos(proxy);
    return 0;
}

struct wl_proxy *wl_proxy_marshal_flags(struct wl_proxy *proxy, uint32_t opcode, const struct wl_interface *interface, uint32_t version, uint32_t flags, ...) {
    resolve();
    union wl_argument args[MAX_ARGS];
    memset(args, 0, sizeof args);
    const struct wl_interface *iface = get_interface ? get_interface(proxy) : NULL;
    va_list ap;
    va_start(ap, flags);
    args_from_va(iface && (int)opcode < iface->method_count ? iface->methods[opcode].signature : "", args, ap);
    va_end(ap);
    if (look(proxy, opcode, args))
        return NULL;
    return marshal_array_flags ? marshal_array_flags(proxy, opcode, interface, version, flags, args) : NULL;
}

void wl_proxy_marshal(struct wl_proxy *proxy, uint32_t opcode, ...) {
    resolve();
    union wl_argument args[MAX_ARGS];
    memset(args, 0, sizeof args);
    const struct wl_interface *iface = get_interface ? get_interface(proxy) : NULL;
    va_list ap;
    va_start(ap, opcode);
    args_from_va(iface && (int)opcode < iface->method_count ? iface->methods[opcode].signature : "", args, ap);
    va_end(ap);
    if (look(proxy, opcode, args))
        return;
    if (marshal_array)
        marshal_array(proxy, opcode, args);
}
