#!/bin/bash

cat local.repo > /etc/yum.repos.d/local.repo
yum clean all

yum install mock createrepo ccache -y
yum install perl-Config-YAML perl-WWW-Mechanize perl-DBI perl-DBD-Pg  -y

username='build'
/usr/sbin/useradd $username
/usr/sbin/usermod -a -G mock $username
/usr/sbin/usermod -a -G wheel $username

#/bin/cat /etc/sz-build-sys/default.cfg > /etc/mock/default.cfg

#build_env='/home/build/enviroment'
#/bin/mkdir -p $build_env
#/bin/cp /opt/sz-build-sys/builder.rb $build_env
#/bin/cp -R /opt/sz-build-sys/modules $build_env
#/bin/chmod -R 755 $build_env
#/bin/chown -R build $build_env

