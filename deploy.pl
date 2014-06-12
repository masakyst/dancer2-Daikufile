#!/usr/bin/env perl

use YAML;
use File::Basename;
use Cinnamon::DSL;

my %production_config = ( 
    %{ YAML::LoadFile('config.yml') },
    %{ YAML::LoadFile('environments/production.yml') }
);  

# configuration
set application => basename($production_config{appdir});
set repository  => sprintf 'git@bitbucket.org:***************/%s.git', get('application');
set deploy_dir  => dirname($production_config{appdir});
set deploy_to   => sprintf "%s/%s", get('deploy_dir'), get('application');
set tty         => 1;


# server roles
role 'production' => '***********.domain', {
    user     => $production_config{user},
    group    => $production_config{group},
    password => $production_config{password},
};


# tasks
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
    my ($stdout, $stderr) = remote {
        run "cd ${deploy_dir} && git clone ${repository}";
        run "cd ${deploy_to} && carton install --deployment";
        # initialize   
        # run "cd ${deploy_to} && carton exec daiku [initialize task]";
        # setup initd script
        #sudo "cp ${deploy_to}/init.d/[daemon] /etc/init.d/";
        #sudo "/sbin/chkconfig --add [daemon]";
        #sudo "mkdir -p /var/run/[daemon]";
        #sudo "chown ${user}:${group} /var/run/[daemon]";
        #sudo "cp ${deploy_to}/logrotate.d/[daemon] /etc/logrotate.d/";
    } $host;
};

task start => sub {
    my $host = shift;
    my ($stdout, $stderr) = remote {
        sudo "service [daemon] start";
    } $host;
};

task stop => sub {
    my $host = shift;
    my ($stdout, $stderr) = remote {
        sudo "service [daemon] stop";
    } $host;
};

task restart => sub {
    my $host = shift;
    my ($stdout, $stderr) = remote {
        sudo "service [daemon] restart";
    } $host;
};

task status => sub {
    my $host = shift;
    my ($stdout, $stderr) = remote {
        sudo "service [daemon] status";
    } $host;
};

