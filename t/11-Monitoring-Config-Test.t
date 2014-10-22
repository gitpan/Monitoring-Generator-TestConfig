#!/usr/bin/env perl

use Test::More;
use File::Temp qw{ tempdir };

use_ok('Monitoring::Generator::TestConfig');
my $cleanup = 1;
my $test_dir = tempdir(CLEANUP => $cleanup);
my $mgt = Monitoring::Generator::TestConfig->new( 'output_dir' => $test_dir, 'overwrite_dir' => 1 );

if(!defined $mgt->{'binary'}) {
   plan( skip_all => 'no nagios(3)/icinga bin found in path, skipping config test' );
}

# which layouts to test
my @layouts = qw/nagios icinga/;

########################################

$configtests = {
    "simple standard" => { 'overwrite_dir' => 1 },
    "simple prefix"   => { 'overwrite_dir' => 1, 'prefix' => 'pre_' },
    "small standard"  => { 'overwrite_dir' => 1, 'routercount' =>  1, 'hostcount' =>   1, 'services_per_host' =>  1 },
    "medium standard" => { 'overwrite_dir' => 1, 'routercount' => 30, 'hostcount' => 400, 'services_per_host' => 25 },
    "complex config"  => { 'overwrite_dir' => 1,
                           'routercount'               => 5,
                           'hostcount'                 => 50,
                           'services_per_host'         => 10,
                           'main_cfg'                  => {
                                   'execute_service_checks'  => 0,
                               },
                           'hostfailrate'              => 2,
                           'servicefailrate'           => 5,
                           'host_settings'             => {
                                   'check_interval'          => 30,
                                   'check_interval'          => 5,
                               },
                           'service_settings'          => {
                                   'check_interval'          => 30,
                                   'check_interval'          => 5,
                               },
                           'router_types'              => {
                                           'down'         => 20,
                                           'up'           => 20,
                                           'flap'         => 20,
                                           'pending'      => 20,
                                           'random'       => 20,
                               },
                           'host_types'                => {
                                           'down'         => 5,
                                           'up'           => 50,
                                           'flap'         => 5,
                                           'pending'      => 5,
                                           'random'       => 35,
                               },
                           'service_types'             => {
                                           'ok'           => 50,
                                           'warning'      => 5,
                                           'unknown'      => 5,
                                           'critical'     => 5,
                                           'pending'      => 5,
                                           'flap'         => 5,
                                           'random'       => 25,
                               },
                         },
};

for my $name (keys %{$configtests}) {
    for my $layout (@layouts) {
        my $test_dir = tempdir(CLEANUP => $cleanup);

        my $conf = $configtests->{$name};
        $conf->{'layout'}     = $layout;
        $conf->{'output_dir'} = $test_dir;
        my $mgt = Monitoring::Generator::TestConfig->new( %{$conf} );
        isa_ok($mgt, 'Monitoring::Generator::TestConfig');
        $mgt->create();

        my $testcommands = [
            $mgt->{'binary'}.' -v '.$test_dir.'/'.$mgt->{'layout'}.'.cfg',
            $test_dir.'/init.d/'.$mgt->{'layout'}.' checkconfig',
        ];
        # add some author tests
        if($ENV{TEST_AUTHOR} ) {
            push @{$testcommands}, $test_dir.'/init.d/'.$mgt->{'layout'}.' start';
            push @{$testcommands}, $test_dir.'/init.d/'.$mgt->{'layout'}.' status';
            push @{$testcommands}, $test_dir.'/init.d/'.$mgt->{'layout'}.' stop';
        }

        for $cmd (@{$testcommands}) {
            open(my $ph, '-|', $cmd) or die('exec "'.$cmd.'" failed: $!');
            my $output = "";
            while(<$ph>) {
                $output .= $_;
            }
            close($ph);
            my $rt = $?>>8;
            is($rt,0,"$name: $cmd") or BAIL_OUT($output);
        }
    }
}

done_testing();
