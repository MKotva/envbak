# envbak
Command-line utility for simple backup and restore of user-space environment.
1) For best testing of this utility use lxc with arch container.
2) Create container: lxc-create -n playtime -t download -- --dist archlinux
3) Run bash in container: lxc-start -n CONTAINER_NAME [-f config] [/bin/bash]
4) Restore archive in this dir.
