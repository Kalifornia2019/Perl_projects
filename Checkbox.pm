package Checkbox;
=head1 NAME

  Модуль взаимодействия с сервисом "Checkbox" Ukraine


=head1 VERSION

  VERSION: 0.01
  DATE: 20210203

=cut

use strict;
use warnings FATAL => 'all';

use JSON;
use utf8 qw/encode/;
use Abills::Base qw(_bp);
use Abills::Fetcher;

my $VERSION = 0.01;
my $api_url = '';
my $curl    = '';
my $access_token ='';

#**********************************************************
=head2 new($conf, $attr)

=cut
#**********************************************************
sub new {
  my ($class, $conf, $attr) = @_;

  $api_url = $attr->{url};
  $curl    = $conf->{FILE_CURL} || 'curl';
  
  my $self = {
    APP_ID        => $attr->{login},
    SECRET        => $attr->{password},
    X_LICENSE_KEY => $attr->{x_license_key},
   # goods   => $attr->{goods_name},
   # author  => $attr->{author},
   # api     => $attr->{api_name},
    VERSION => $VERSION
  };
  
  bless($self, $class);
  
  return $self;
}

#**********************************************************
=head2 init()

=cut
#**********************************************************
sub init {
  my $self = shift;

  my $url = $api_url . '/api/v1/cashier/signin';

  my $json_hash = {
    "login"      => "$self->{login}" ,
    "password"   => "$self->{password}"
  };

  my $json_request = JSON::encode_json($json_hash);
  $json_request =~ s/\n//g;

  my $token = web_request($url,
    {
      HEADERS         => [ "Content-Type: application/json" ],
      DEBUG           => ($self->{debug}) ? 6 : 0,
      JSON_RETURN     => 1,
      REQUEST_PARAMS  => "$json_request"
    }
  );

  $access_token = "$token->{access_token}";

  return 1;
}

#**********************************************************
=head2 closed_shifts()

=cut
#**********************************************************
sub closed_shifts {
  my $self = shift;

  my $url = $api_url . '/api/v1/shifts';

  my $add_shifts = web_request($url,
    {
      HEADERS         => [ "X-License-Key: $self->{x_license_key}" ],
      DEBUG           => ($self->{debug}) ? 6 : 0,
      JSON_RETURN     => 1
    }
  );

  if($add_shifts->{status} eq "CREATED"){

  }
  else{

  }

  $access_token = "$token->{access_token}";

  return 1;
}
#**********************************************************
=head2 payment_register($attr)

  Регистрирует платеж в онлайн-кассе

=cut
#**********************************************************
sub payment_register {
  my $self = shift;
  my ($attr) = @_;

  if ($self->{debug}) {
    print "\nTry \\printCheck for payment $attr->{payments_id}\n";
  }
  
  my %data = (
    nonce          => $self->get_nonce(),
    app_id         => $self->{APP_ID},
    token          => $self->{TOKEN},
    type           => "printCheck",
    command => {
      smsEmail54FZ   => ($attr->{c_phone} || $attr->{phone} || $attr->{mail} || ''),
      payed_cash     => '0',
      payed_cashless => $attr->{sum},
      author         => $self->{author},
      c_num          => $attr->{payments_id},
      goods  => [{
        count     => 1,
        price     => $attr->{sum},
        sum       => $attr->{sum},
        name      => $self->{goods},
        item_type => 4,
        # nds_value       => 0, 
        nds_not_apply   => 'true',
      }]
    }
  );

  my $sign  = $self->get_sign(\%data);
  my $p_data = $self->perl2json(\%data);

  my $params = qq(-d '$p_data' -H "sign: $sign" -H "Content-Type: application/json");
  my $url = $api_url . "Command";
  my $result = `$curl $params -s -X POST "$url"`;
  my $perl_hash = ();
  eval { $perl_hash = decode_json($result); 1 };
  if ($self->{debug}) {
    print "CMD: $curl $params -s -X POST '$url'\n";
    print "RESULT: $result\n";
  }

  return $perl_hash->{command_id} || 0;
}

#**********************************************************
=head2 get_info($id) - Получает информацию по ранее зарегистрированному платежу

  Arguments:
    $attr
      command_id

  Result:
    fiscal_document_number, fiscal_document_attribute, receipt_datetime, c_num, 0

=cut
#**********************************************************
sub get_info {
  my $self = shift;
  my ($attr) = @_;

  my %data = (
    nonce  => $self->get_nonce(),
    app_id => $self->{APP_ID},
    token  => $self->{APP_ID},
  );
  my $sign  = $self->get_sign(\%data);
  my $query = $self->make_query(\%data);

  my $params = qq/-H "sign: $sign"/;
  my $url = $api_url . "Command/$attr->{command_id}?" . $query;
  my $result = `$curl -s '$url' $params`;
  if ($self->{debug}) {
    print "CMD: $curl -s '$url' $params\n";
    print "RESULT: $result\n";
  }
  my $perl_hash = ();
  eval { $perl_hash = decode_json($result); 1 };

  if ($perl_hash->{id}) {
    return (
      $perl_hash->{fiscal_document_number},
      $perl_hash->{fiscal_document_attribute},
      $perl_hash->{receipt_datetime} || q{},
      $perl_hash->{command}->{c_num},
      0
    );
  }

  return (0, 0, 0, $perl_hash->{command}->{c_num}, 1);
}

#**********************************************************
=head2 get_sign($data)

  Arguments:
    $data

  Result:
    $sign

=cut
#**********************************************************
sub get_sign {
  my $self = shift;
  my ($data) = @_;

  my $json_str = $self->perl2json($data);
  my $data_str = $json_str . $self->{SECRET};
  my $sign = md5_hex($data_str);

  return $sign;
}

#**********************************************************
=head2 make_query($data)

=cut
#**********************************************************
sub make_query {
  my $self = shift;
  my ($data) = @_;
  my $query_str = "";

  foreach my $key (sort keys %$data) {
    $query_str .= "&" if ($query_str);
    $query_str .= "$key=$data->{$key}";
  }

  return $query_str;
}

#**********************************************************
=head2 perl2json()

=cut
#**********************************************************
sub perl2json {
  my $self = shift;
  my ($data) = @_;
  my @json_arr = ();

  if (ref $data eq 'ARRAY') {
    foreach my $key (@{$data}) {
      push @json_arr, $self->perl2json($key);
    }
    return '[' . join(',', @json_arr) . "]";
  }
  elsif (ref $data eq 'HASH') {
    foreach my $key (sort keys %$data) {
      my $val = $self->perl2json($data->{$key});
      push @json_arr, qq{\"$key\":$val};
    }
    return '{' . join(',', @json_arr) . "}";
  }
  else {
    $data //='';
    return qq{\"$data\"};
  }
}

#**********************************************************
=head2 payment_cancel($attr)

  Регистрирует отмену чека в онлайн-кассе

=cut
#**********************************************************
sub payment_cancel {
  my $self = shift;
  my ($attr) = @_;

  if ($self->{debug}) {
    print "\nTry \\printPurchaseReturn for payment $attr->{payments_id}\n";
  }
  
  my %data = (
    nonce          => $self->get_nonce(),
    app_id         => $self->{APP_ID},
    token          => $self->{TOKEN},
    type           => "printPurchaseReturn",
    command => {
      smsEmail54FZ   => ($attr->{c_phone} || $attr->{phone} || $attr->{mail} || ''),
      payed_cash     => '0',
      payed_cashless => $attr->{sum},
      author         => $self->{author},
      c_num          => "n" . $attr->{payments_id},
      goods  => [{
        count => 1,
        price => $attr->{sum},
        sum   => $attr->{sum},
        name  => $self->{goods},
        nds_not_apply   => 'true',
      }]
    }
  );

  my $sign  = $self->get_sign(\%data);
  my $p_data = $self->perl2json(\%data);

  my $params = qq(-d '$p_data' -H "sign: $sign" -H "Content-Type: application/json");
  my $url = $api_url . "Command";
  my $result = `$curl $params -s -X POST "$url"`;
  my $perl_hash = decode_json($result);
  if ($self->{debug}) {
    print "CMD: $curl $params -s -X POST '$url'\n";
    print "RESULT: $result\n";
  }

  return $perl_hash->{command_id} || 0;
}


#**********************************************************
=head2 test() - Connect test

=cut
#**********************************************************
sub test {
  my $self = shift;

  $self->make_request({
    CMD => 'StateSystem',
  });

  $self->{test_result}=$self->{request_result};

  return $self;
}

#**********************************************************
=head2 make_request($attr) - Тест подключения

  Arguments:
    $attr
      CMD
      REQUEST_DATA - request_datahash
      GET

  Results:
    $self

=cut
#**********************************************************
sub make_request {
  my $self = shift;
  my ($attr) = @_;

  my $url  = $api_url.$attr->{CMD};
  my %data = (
    login    => $self->{login},
    password =>  $self->{password}
  );

  if ($self->{TOKEN}) {
    $data{token}=$self->{TOKEN};
  }

  if ($attr && defined($attr->{REQUEST_DATA}) && ref $attr->{REQUEST_DATA} eq 'HASH') {
    %data =  ( %data, %{ $attr->{REQUEST_DATA} } );
  }

  my %request_params = ();
  if ($attr->{PUSH}) {
    my $post_data = $self->perl2json(\%data);
    $request_params{POST} = $post_data;
  }
  else {
    my $query = $self->make_query(\%data);
    $url .= '?' . $query;
  }

  my $result = web_request($url,
    {
      HEADERS => [
        "sign: $sign",
        "Content-Type: application/json"
      ],
      DEBUG       => ($self->{debug}) ? 6 : 0,
      JSON_RETURN => 1,
      %request_params
    }
  );

  $self->{request_result}=$result;

  if ($result->{result} && $result->{result} > 0) {
    $self->{errno}=$result->{result};
    $self->{error}=$result->{result};
    $self->{errstr}=$result->{message};
  }

  return $self;
}

1