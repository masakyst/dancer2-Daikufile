#!/usr/bin/env perl

use lib 'lib';
use YAML;
use File::Basename;
use Cinnamon::DSL;

package TemporaryDancerConfig { 
    use Moo; with 'Dancer2::Core::Role::ConfigReader';
    sub prog_name { 
        (my $prog_name = lc shift->config->{appname}) =~ s/::/\-/;
        return $prog_name; 
    }
};

my $DANCER_CONFIG = TemporaryDancerConfig->new;

# configuration
set application => basename($DANCER_CONFIG->config->{appdir});
set repository  => sprintf 'git@bitbucket.org:[youraccount]/%s.git', get('application');
set deploy_dir  => dirname($DANCER_CONFIG->config->{appdir});
set deploy_to   => sprintf "%s/%s", get('deploy_dir'), get('application');
set tty         => 1;


role 'production' => '[domain]', {
    user     => $DANCER_CONFIG->config->{user},
    group    => $DANCER_CONFIG->config->{group},
    password => $DANCER_CONFIG->config->{password},
};


task test => sub {
    my $host = shift;
    my ($res, $err) = remote {
        sudo "ls -la /usr/local/bin";
    } $host;
};

task install => sub {
    my $host = shift;
    my $application = get 'application';
    my $repository  = get 'repository';
    my $deploy_dir  = get 'deploy_dir';
    my $deploy_to   = get 'deploy_to';
    my $user        = get 'user';
    my $group       = get 'group';
    my $plack_env   = $DANCER_CONFIG->environment;
    my $prog_name   = $DANCER_CONFIG->prog_name;
    my ($stdout_git, $stderr_git) = remote {
        run "cd ${deploy_dir} && git clone ${repository}";
        run "cd ${deploy_to} && carton install --deployment";
    } $host;
    run ("scp", "environments/${plack_env}.yml", "${user}\@${host}:${deploy_to}/environments/${plack_env}.yml");
    run ("scp", "init.d/setting", "${user}\@${host}:${deploy_to}/init.d/setting");
    my ($stdout_initd, $stderr_initd) = remote {
        # run "cd ${deploy_to} && carton exec daiku [initialize task]";
        sudo "cp ${deploy_to}/init.d/${prog_name} /etc/init.d/";
        sudo "/sbin/chkconfig --add ${prog_name}";
        sudo "mkdir -p /var/run/${prog_name}";
        sudo "chown ${user}:${group} /var/run/${prog_name}";
        sudo "cp ${deploy_to}/logrotate.d/${prog_name} /etc/logrotate.d/";
    } $host;
};

task start => sub {
    my $host = shift;
    my $prog_name = $DANCER_CONFIG->prog_name;
    my ($stdout, $stderr) = remote {
        sudo "service ${prog_name} start";
    } $host;
};

task stop => sub {
    my $host = shift;
    my $prog_name = $DANCER_CONFIG->prog_name;
    my ($stdout, $stderr) = remote {
        sudo "service ${prog_name} stop";
    } $host;
};

task restart => sub {
    my $host = shift;
    my $prog_name = $DANCER_CONFIG->prog_name;
    my ($stdout, $stderr) = remote {
        sudo "service ${prog_name} restart";
    } $host;
};

task status => sub {
    my $host = shift;
    my $prog_name = $DANCER_CONFIG->prog_name;
    my ($stdout, $stderr) = remote {
        sudo "service ${prog_name} status";
    } $host;
};

task update => sub {
    my $host = shift;
    my $deploy_to   = get 'deploy_to';
    my ($gitclone, $stderr_gitpull) = remote {
        run "cd ${deploy_to} && git pull";
    } $host;
};

