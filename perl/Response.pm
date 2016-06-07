package Response;

use File::Basename;
my $dirname = dirname(__FILE__);
use lib "$dirname/Response";
my $path  = "$dirname/Response/*.pm";
my @files = < $path >;
foreach my $fullname (@files) {

    # TO LOG: system("echo \"**** $mod requiring $fullname\" >> log_module_Response");
    require $fullname;
}

1;

__END__
