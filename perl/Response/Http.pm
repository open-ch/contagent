package Response::Http;

use nginx;

# Set status code of response
sub set_status_code {
    my $r = shift;
    $r->status($r->variable('status_code'));
    $r->send_http_header;
    return OK;
}

# Set long header in response
sub set_long_header {
    my $r          = shift;
    my $n          = $r->variable('bytes');
    my $header_key = "Long-Header";
    my $bytes      = '>' x ($n - length($header_key));
    $r->header_out($header_key, $bytes);
    $r->send_http_header;
    return OK;
}

# Set header with n null-bytes in response
sub set_nullbytes {
    my $r = shift;
    my $nullbytes = "\x00" x ($r->variable('nullbytes'));
    $r->header_out("Nullbyte-Header", "wnmp-nginx/1.5.13$nullbytes");
    $r->send_http_header;
    return OK;
}

# Set response with custom Content-Type field
sub set_content_type {
    my $r             = shift;
    my $con_type_cat  = $r->variable('con_type_cat');
    my $con_type_file = $r->variable('con_type_file');
    my $header        = $con_type_cat;
    if ($con_type_file) {
        $header .= "/$con_type_file";
    }
    $r->send_http_header($header);
    return OK;
}

# Set any custom header
sub set_custom_header {
    my $r            = shift;
    my $header_key   = $r->variable('header_key');
    my $header_value = $r->variable('header_value');
    $r->header_out($header_key, $header_value);
    $r->send_http_header;
    return OK;
}

# Set many custom headers
sub set_many_custom_headers {
    my $r            = shift;
    my $header_key   = $r->variable('header_key');
    my $header_value = $r->variable('header_value');
    my $header_count = $r->variable('header_count');
    for my $i (1 .. $header_count) {
        $r->header_out($header_key, $header_value);
    }
    $r->send_http_header;
    return OK;
}

1;

__END__
