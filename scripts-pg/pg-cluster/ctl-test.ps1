#D:\git\ps-modules\scripts-pg\pg-cluster\ctl.ps1 send-wal2ftp

#D:\git\ps-modules\scripts-pg\pg-cluster\ctl.ps1 backup-clusters

# Backup all bases form all clusters
#D:\git\ps-modules\scripts-pg\pg-cluster\ctl.ps1 backup-bases

D:\git\ps-modules\scripts-pg\pg-cluster\ctl.ps1 Add-Cluster -c test12 -p 5442 -pwd 'test5441' -initcluster

# Backup only base from one cluster.
#D:\git\ps-modules\scripts-pg\pg-cluster\ctl.ps1 backup-bases -c test3 -b test5433-base0

#D:\git\ps-modules\scripts-pg\pg-cluster\ctl.ps1 remove-backups

#D:\git\ps-modules\scripts-pg\pg-cluster\ctl.ps1 init-clusters