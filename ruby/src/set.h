extern void do_name(dbref player, const char *name, char *newname);
extern void do_describe(dbref player, const char *name, const char *description);
extern void do_fail(dbref player, const char *name, const char *message);
extern void do_success(dbref player, const char *name, const char *message);
extern void do_osuccess(dbref player, const char *name, const char *message);
extern void do_ofail(dbref player, const char *name, const char *message);
extern void do_lock(dbref player, const char *name, const char *keyname);
extern void do_unlock(dbref player, const char *name);
extern void do_unlink(dbref player, const char *name);
extern void do_chown(dbref player, const char *name, const char *newobj);
extern void do_set(dbref player, const char *name, const char *flag);
