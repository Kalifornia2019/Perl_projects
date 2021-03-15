#package Paysys::Configure;

use strict;
use warnings FATAL => 'all';
use Abills::Base qw(cmd);
use Paysys;
use Users;


our ($db,
  %conf,
  $admin,
  $op_sid,
  %lang,
#  $base_dir,
  %ADMIN_REPORT,
  %PAYSYS_PAYMENTS_METHODS,
  @WEEKDAYS,
  @MONTHES,
  %FEES_METHODS,
  @TERMINAL_STATUS,
);

our Paysys $Paysys;
our Abills::HTML $html;
my $Users = Users->new($db, $admin, \%conf);


#**********************************************************
=head2 paysys_configure_main()

=cut
#**********************************************************
sub paysys_configure_main {
  our $Conf = Conf->new($db, $admin, \%conf);
  #my $paysys_folder = "$base_dir" . 'Abills/modules/Paysys/systems/';

  # show form for paysys connection
  if ($FORM{add_form}) {
    my $btn_value = $lang{ADD};
    my $btn_name = 'add_paysys';
    my ($paysys_select, $json_list) = _paysys_select_systems();

    $html->tpl_show(
      _include('paysys_connect_system', 'Paysys'),
      {
        BTN_VALUE          => $btn_value,
        BTN_NAME           => $btn_name,
        PAYSYS_SELECT      => $paysys_select,
        JSON_LIST          => $json_list,
        PAYMENT_METHOD_SEL => _paysys_select_payment_method(),
      },
    );
  }

  # add system in paysys connection
  if ($FORM{add_paysys}) {
    if ($FORM{create_payment_method}) {
      require Payments;
      Payments->import();
      my $Payments = Payments->new($db, $admin, \%conf);

      $Payments->payment_type_add({
        NAME  => $FORM{NAME} || '',
        COLOR => '#000000'
      });
      $FORM{PAYMENT_METHOD} = $Payments->{INSERT_ID};
    }

    $Paysys->paysys_connect_system_add({
      PAYSYS_ID      => $FORM{PAYSYS_ID},
      NAME           => $FORM{NAME},
      MODULE         => $FORM{MODULE},
      PAYSYS_IP      => $FORM{IP},
      STATUS         => $FORM{STATUS},
      PAYMENT_METHOD => $FORM{PAYMENT_METHOD},
      PRIORITY       => $FORM{PRIORITY}
    });

    my $payment_system = $FORM{MODULE};
    my $require_module = _configure_load_payment_module($payment_system);

    if ($require_module->can('get_settings')) {
      my $config = Conf->new($db, $admin, \%conf);
      my %settings = $require_module->get_settings();

      foreach my $key (sort keys %{$settings{CONF}}) {
        if ($key =~ /_NAME_/) {
          my $new_key = $key;
          my $new_name = uc($FORM{NAME});
          $new_key =~ s/_NAME_/_$new_name\_/;
          $FORM{$key} =~ s/"/\\"/g;
          $config->config_add({ PARAM => $new_key, VALUE => $FORM{$key}, REPLACE => 1 });
        }
        else {
          $FORM{$key} =~ s/"/\\"/g;
          $config->config_add({ PARAM => $key, VALUE => $FORM{$key}, REPLACE => 1 });
        }
      }

    }

    if (!_error_show($Paysys)) {
      $html->message('info', $lang{SUCCESS}, $lang{ADDED});
    }
  }

  # change %CONF params in db
  if ($FORM{change}) {
    my $config = Conf->new($db, $admin, \%conf);

    my $payment_system = $FORM{MODULE};
    my $require_module = _configure_load_payment_module($payment_system);

    if ($require_module->can('get_settings')) {
      my %settings = $require_module->get_settings();

      foreach my $key (sort keys %{$settings{CONF}}) {
        if ($key =~ /_NAME_/) {
          my $old_name = uc($FORM{OLD_NAME});
          $key =~ s/_NAME_/_$old_name\_/;
        }
        my $new_key = $key;

        if ($FORM{NAME} ne $FORM{OLD_NAME}) {
          my $old_name = uc($FORM{OLD_NAME});
          my $name = uc($FORM{NAME});
          $new_key =~ s/$old_name/$name/;
        }

        if (defined $FORM{$key} && $FORM{$key} ne '') {
          $FORM{$key} =~ s/"/\\"/g;
          $config->config_add({ PARAM => $new_key, VALUE => $FORM{$key}, REPLACE => 1 });
        }
        else {
          $FORM{$key} =~ s/"/\\"/g;
          $config->config_del($key);
        }

      }
    }

    if ($FORM{create_payment_method}) {
      require Payments;
      Payments->import();
      my $Payments = Payments->new($db, $admin, \%conf);

      $Payments->payment_type_add({
        NAME  => $FORM{NAME} || '',
        COLOR => '#000000'
      });
      $FORM{PAYMENT_METHOD} = $Payments->{INSERT_ID};
    }

    $Paysys->paysys_connect_system_change({
      %FORM,
      PAYSYS_IP => $FORM{IP},
    });
  }
  elsif ($FORM{del}) {
    $Paysys->paysys_connect_system_delete({
      ID => $FORM{del},
      %FORM
    });
    _error_show($Paysys);
  }

  if ($FORM{chg}) {
    my $btn_value = $lang{CHANGE};
    my $btn_name = 'change';

    my $connect_system_info = $Paysys->paysys_connect_system_info({
      ID               => $FORM{chg},
      SHOW_ALL_COLUMNS => 1,
      COLS_NAME        => 1,
      COLS_UPPER       => 1,
    });

    my ($paysys_select, $json_list) = _paysys_select_systems($connect_system_info->{name}, $connect_system_info->{paysys_id}, { change => 1 });

    $html->tpl_show(
      _include('paysys_connect_system', 'Paysys'),
      {
        PAYSYS_SELECT      => $paysys_select,
        JSON_LIST          => $json_list,
        BTN_VALUE          => $btn_value,
        BTN_NAME           => $btn_name,
        ($connect_system_info && ref $connect_system_info eq "HASH" ? %$connect_system_info : ()),
        #        %$connect_system_info,
        ACTIVE             => $connect_system_info->{status},
        IP                 => $connect_system_info->{paysys_ip},
        PRIORITY           => $connect_system_info->{priority},
        HIDE_SELECT        => 'hidden',
        ID                 => $FORM{chg},
        PAYMENT_METHOD_SEL => _paysys_select_payment_method({ PAYMENT_METHOD => $connect_system_info->{payment_method} }),
      },
    );
  }

  # table to show all systems in folder
  my $table_for_systems = $html->table(
    {
      caption    => "",
      width      => '100%',
      title      =>
        [ '#', $lang{PAY_SYSTEM}, $lang{MODULE}, $lang{VERSION}, $lang{STATUS}, 'IP', $lang{PRIORITY}, $lang{PERIODIC}, $lang{REPORT}, $lang{TEST}, '', '' ],
      MENU       => "$lang{ADD}:index=$index&add_form=1:add",
      DATA_TABLE => 1,
    }
  );

  my $systems = $Paysys->paysys_connect_system_list({
    SHOW_ALL_COLUMNS => 1,
    COLS_NAME        => 1,
    PAGE_ROWS        => 100,
  });

  foreach my $payment_system (@$systems) {

    my $require_module = _configure_load_payment_module($payment_system->{module});
    # check if module already on new verision and has get_settings sub
    if ($require_module->can('get_settings')) {
      my %settings = $require_module->get_settings();

      my $status = $payment_system->{status} || 0;
      my $paysys_name = $payment_system->{name} || '';
      my $id = $payment_system->{id} || 0;
      my $paysys_id = $payment_system->{paysys_id} || 0;
      my $paysys_ip = $payment_system->{paysys_ip} || '';
      my $priority = $payment_system->{priority} || 0;

      $status = (!($status) ? $html->color_mark("$lang{DISABLE}", 'danger') : $html->color_mark(
        "$lang{ENABLE}",
        'success'));

      my $change_button = $html->button("$lang{CHANGE}",
        "index=$index&MODULE=$payment_system->{module}&chg=$id&PAYSYSTEM_ID=$paysys_id",
        { class => 'change' });
      my $delete_button = $html->button("$lang{DEL}",
        "index=$index&MODULE=$payment_system->{module}&del=$id&PAYSYSTEM_ID=$paysys_id",
        { class => 'del', MESSAGE => "$lang{DEL} $paysys_name", });
      my $test_button = '';
      if ($require_module->can('has_test') && $payment_system->{status} == 1) {
        my $test_index = get_function_index('paysys_main_test');
        $test_button = $html->button("$lang{START_PAYSYS_TEST}",
          "index=$test_index&MODULE=$payment_system->{module}&PAYSYSTEM_ID=$paysys_id",
          { class => 'btn btn-success btn-xs' });
      }
      elsif ($require_module->can('has_test')) {
        $test_button = $lang{PAYSYS_MODULE_NOT_TURNED_ON};
      }
      else {
        $test_button = $lang{NOT_EXIST};
      }

      $table_for_systems->addrow(
        $paysys_id,
        $paysys_name,
        $payment_system->{module},
        $settings{VERSION},
        $status,
        $paysys_ip,
        $priority,
        $require_module->can('periodic') ? $html->color_mark("$lang{YES}", 'success') : $html->color_mark("$lang{NO}", '#f04'),
        $require_module->can('report') ? $html->color_mark("$lang{YES}", 'success') : $html->color_mark("$lang{NO}", '#f04'),
        $test_button,
        $change_button,
        $delete_button,
      );
    }

  }

  print $table_for_systems->show();

  return 1;
}

#**********************************************************
=head2 paysys_groups_settings() - check whats

=cut
#**********************************************************
sub paysys_configure_groups {

  if ($FORM{add_settings}) {
    # truncate settings table
    $Paysys->groups_settings_delete({});
    _error_show($Paysys);
  }

  # get groups list
  my $groups_list = $Users->groups_list({
    COLS_NAME      => 1,
    DISABLE_PAYSYS => 0,
    GID             => '_SHOW',
    NAME            => '_SHOW',
    DESCR           => '_SHOW',
    ALLOW_CREDIT    => '_SHOW',
    DISABLE_PAYSYS  => '_SHOW',
    DISABLE_CHG_TP  => '_SHOW',
    USERS_COUNT     => '_SHOW',
  });

  # get payment systems list
  #  my %connected_payment_systems = paysys_system_sel({ ONLY_SYSTEMS => 1 });
  my $connected_payment_systems = $Paysys->paysys_connect_system_list({
    SHOW_ALL_COLUMNS => 1,
    STATUS           => 1,
    COLS_NAME        => 1,
  });

  if (ref $connected_payment_systems ne 'ARRAY' || !scalar(@$connected_payment_systems)) {
    $html->message('err', 'No payments system connected');
    return 1;
  }

  my @connected_payment_systems = ('#', $lang{GROUPS});
  foreach my $system (sort @$connected_payment_systems) {
    push(@connected_payment_systems, $system->{name});
  }

  # table for settings
  my $table = $html->table(
    {
      width   => '100%',
      caption => "$lang{PAYSYS_SETTINGS_FOR_GROUPS}",
      title   => \@connected_payment_systems,
      ID      => 'PAYSYS_GROUPS_SETTINGS',
    }
  );

  # get settings from db
  my $list_settings = $Paysys->groups_settings_list({
    GID       => '_SHOW',
    PAYSYS_ID => '_SHOW',
    COLS_NAME => 1,
    PAGE_ROWS => 99999,
  });

  my %groups_settings = ();

  foreach my $gid_settings (@$list_settings) {
    $groups_settings{"SETTINGS_$gid_settings->{gid}_$gid_settings->{paysys_id}"} = 1;
  }

  # form rows for table
  foreach my $group (@$groups_list) {
    my @rows;
    next if $group->{disable_paysys} == 1;

    foreach my $system (sort @$connected_payment_systems) {
      my $input_name = "SETTINGS_$group->{gid}_$system->{paysys_id}";
      if ($FORM{add_settings} && $FORM{$input_name}) {
        $Paysys->groups_settings_add({
          GID       => $group->{gid},
          PAYSYS_ID => $system->{paysys_id},
        });
      }
      my $checkbox = $html->form_input("$input_name", "1",
        { TYPE => 'checkbox', STATE => (($FORM{$input_name} || $groups_settings{$input_name}) ? 'checked' : '') });

      my $settings_button = $html->button("$lang{SETTINGS}",
        "get_index=paysys_get_module_settings&MERCHANT=$group->{gid}&MODULE=$system->{module}&chg=1&PAYSYSTEM_ID=$system->{paysys_id}&NAME=$system->{name}&header=2",
        {
          class         => 'btn-xs',
          LOAD_TO_MODAL => 1,
        });
      push(@rows, "$lang{LOGON}" . $checkbox . "<br>" . $settings_button);

    }
    $table->addrow($group->{gid}, $group->{name}, @rows);
  }
  _error_show($Paysys);

  # form for sending settings
  print $html->form_main(
    {
      CONTENT => $table->show(),
      HIDDEN  => {
        index => "$index",
        #        OP_SID => "$op_sid",
      },
      SUBMIT  => { 'add_settings' => "$lang{CHANGE}" },
      NAME    => 'PAYSYS_GROUPS_SETTINGS'
    }
  );

  return 1;
}

#**********************************************************
=head2 paysys_get_module_settings($attr)

=cut
#**********************************************************
sub paysys_get_module_settings {
  #my ($attr) = @_;

  if (!$FORM{MODULE}) {
    $html->message("err", "No such payment system ");
    return 1;
  }
  elsif ($FORM{MODULE} !~ /^[A-za-z0-9\_]+\.pm$/) {
    $html->message('err', "Permission denied");
    return 1;
  }

  my $MODULE = $FORM{MODULE};
  my $merchant = $FORM{MERCHANT} ? "_$FORM{MERCHANT}" : ''; #_1, _2 ...

  my $Module_object = _configure_load_payment_module($MODULE);

  my %settings = $Module_object->get_settings();

  my $input_html = '';
  foreach my $key (sort keys % {$settings{CONF}}) {
    if ($key =~ /_NAME_/ && $FORM{NAME}) {
      my $name = uc($FORM{NAME});
      $key =~ s/_NAME_/_$name\_/;
    }
    if ($FORM{action}) {
      my $config = Conf->new($db, $admin, \%conf);
      if ($FORM{DELETE_MERCHANT_SETTINGS}) {
        $config->config_del($key . $merchant);
        next;
      }

      $config->config_add({ PARAM => $key . $merchant, VALUE => $FORM{$key . $merchant}, REPLACE => 1 });
      next;
    }
    my $key_value = $conf{$key . $merchant} || $settings{CONF}{$key};
    $key_value =~ s/\%/&#37;/g if $key_value;
    $input_html .= $html->tpl_show(
      _include('paysys_settings_input', 'Paysys'),
      {
        SETTING_LABEL => $key,
        SETTING_NAME  => $key . $merchant,
        SETTING_VALUE => $key_value,
      },
      { OUTPUT2RETURN => 1 }
    );
  }

  $html->message('info', $lang{SUCCESS}) if ($FORM{MESSAGE_ONLY});
  return 1 if $FORM{MESSAGE_ONLY};

  my $template = $html->tpl_show(
    _include('paysys_settings_merchant', 'Paysys'),
    {
      INPUT            => $input_html,
      PAYSYSTEM_NAME   => $MODULE,
      PAYSYSTEM_ID     => $settings{ID},
      NAME             => $FORM{NAME},
      MERCHANT         => $FORM{MERCHANT},
      ACTION           => 'merchant_settings',
      AJAX_SUBMIT_FORM => 'ajax-submit-form'
    }, { OUTPUT2RETURN => 1 }
  );

  if ($FORM{RETURN_TEMPLATE}) {
    return $template
  }
  else {
    print $template;
  }

  return 1;
}

#**********************************************************
=head2 paysys_read_folder_systems()

=cut
#**********************************************************
sub _paysys_select_systems {
  my ($name, $id, $attr) = @_;
  my $systems = _paysys_read_folder_systems();

  my %HASH_TO_JSON = ();
  foreach my $system (@$systems) {
    my $Module = _configure_load_payment_module($system);
    if ($Module->can('get_settings')) {
      my %settings = $Module->get_settings();

      foreach my $key (keys %{$settings{CONF}}) {
        if (defined $name && $name ne '') {
          $name = uc($name);
          delete $settings{CONF}{$key} if $key =~ /_NAME_/;
          $key =~ s/_NAME_/_$name\_/;
          $settings{CONF}{$key} = '';

        }
      }

      @{$settings{CONF}}{keys %{$settings{CONF}}} = @conf{keys %{$settings{CONF}}} if $attr->{change};
      $settings{ID} = $id if (defined $id);

      foreach my $key (keys %{$settings{CONF}}) {
        if ($settings{CONF}{$key}) {
          $settings{CONF}{$key} =~ s/\%/&#37;/g;
        }
      }
      $HASH_TO_JSON{$system} = \%settings;
    }
  }

  my $json_list = JSON->new->utf8(0)->encode(\%HASH_TO_JSON);

  return $html->form_select('MODULE',
    {
      SELECTED    => $FORM{MODULE} || '',
      SEL_ARRAY   => $systems,
      NO_ID       => 1,
      SEL_OPTIONS => { '' => '--' },
    }), $json_list;
}

#**********************************************************
=head2 paysys_select_connected_systems()

=cut
#**********************************************************
sub _paysys_select_connected_systems {
  my ($attr) = @_;

  return $html->form_select('SYSTEM_ID',
    {
      SELECTED    => $attr->{SYSTEM_ID} || $FORM{SYSTEM_ID} || '',
      SEL_LIST    => $Paysys->paysys_connect_system_list({ COLS_NAME => 1, ID => '_SHOW', NAME => '_SHOW', PAGE_ROWS => => 9999 }),
      SEL_KEY     => 'id',
      SEL_VALUE   => 'name',
      NO_ID       => 1,
      SEL_OPTIONS => { '' => '--' },
    });
}

#**********************************************************
=head2 _paysys_select_payment_method()

=cut
#**********************************************************
sub _paysys_select_payment_method {
  my ($attr) = @_;
  my $checkbox = $html->form_input('create_payment_method', '1', {
    TYPE      => 'checkbox',
    EX_PARAMS => "data-tooltip='$lang{CREATE}'  checked",
    ID        => 'create_payment_method',
  }, { OUTPUT2RETURN => 1 }) ;

  return $html->form_select('PAYMENT_METHOD',
    {
      SELECTED    => $FORM{PAYMENT_METHOD} || $attr->{PAYMENT_METHOD} || '',
      SEL_HASH    => \%PAYSYS_PAYMENTS_METHODS,
      NO_ID       => 1,
      SEL_OPTIONS => { '' => '--' },
      SORT_KEY    => 1,
      EXT_BUTTON  => $checkbox ,
    });
}

#**********************************************************
=head2 paysys_configure_external_commands()

=cut
#**********************************************************
sub paysys_configure_external_commands {
  my $action = 'change';
  my $action_lang = "$lang{CHANGE}";
  my %EXTERNAL_COMMANDS_SETTINGS;
  my $Config = Conf->new($db, $admin, \%conf);

  my @conf_params = ('PAYSYS_EXTERNAL_START_COMMAND', 'PAYSYS_EXTERNAL_END_COMMAND',
    'PAYSYS_EXTERNAL_ATTEMPTS', 'PAYSYS_EXTERNAL_TIME');

  if ($FORM{change}) {
    foreach my $conf_param (@conf_params) {
      $Config->config_add({ PARAM => $conf_param, VALUE => $FORM{$conf_param}, REPLACE => 1 });
    }
  }

  foreach my $conf_param (@conf_params) {
    my $param_information = $Config->config_info({ PARAM => $conf_param, DOMAIN_ID => 0 });
    $EXTERNAL_COMMANDS_SETTINGS{$conf_param} = $param_information->{VALUE};
  }

  $html->tpl_show(_include('paysys_external_commands', 'Paysys'), {
    ACTION      => $action,
    ACTION_LANG => $action_lang,
    %EXTERNAL_COMMANDS_SETTINGS
  }, { SKIP_VARS => 'IP UID' });

  return 1;
}

#**********************************************************
=head2 terminals_add() - Adding terminals with location ID

=cut
#**********************************************************
sub paysys_configure_terminals {

  my %TERMINALS;

  $TERMINALS{ACTION} = 'add';     # action on page
  $TERMINALS{BTN} = "$lang{ADD}"; # button name

  $FORM{WORK_DAYS} = 0;
  if ($FORM{WEEK_DAYS}) {
    my @enabled_days = split(', ', $FORM{WEEK_DAYS});
    foreach my $day (@enabled_days) {
      $FORM{WORK_DAYS} += (64 / (2 ** ($day - 1)));
    }
  }

  # if we want to add new terminal
  if ($FORM{ACTION} && $FORM{ACTION} eq 'add') {

    $Paysys->terminal_add({
      %FORM,
      TYPE => $FORM{TERMINAL},
    });
    if (!$Paysys->{errno}) {
      $html->message('success', $lang{ADDED}, "$lang{ADDED} $lang{TERMINAL}");
    }
  }

  # if we want to change terminal
  elsif ($FORM{ACTION} && $FORM{ACTION} eq 'change') {

    $Paysys->terminal_change({
      %FORM,
      TYPE => $FORM{TERMINAL},
    });
    if (!$Paysys->{errno}) {
      $html->message('success', $lang{CHANGED}, "$lang{CHANGED} $lang{TERMINAL}");
    }
  }

  # get info about terminl into page
  if ($FORM{chg}) {
    my $terminal_info = $Paysys->terminal_info($FORM{chg});

    $TERMINALS{ACTION} = 'change';
    $TERMINALS{COMMENT} = $terminal_info->{COMMENT};
    $TERMINALS{DESCRIPTION} = $terminal_info->{DESCRIPTION};
    $TERMINALS{WORK_DAYS} = $terminal_info->{WORK_DAYS};
    $TERMINALS{START_WORK} = $terminal_info->{START_WORK};
    $TERMINALS{END_WORK} = $terminal_info->{END_WORK};
    $TERMINALS{TYPE} = $terminal_info->{TYPE_ID};
    $TERMINALS{BTN} = "$lang{CHANGE}";
    $TERMINALS{ID} = $FORM{chg};
    $TERMINALS{STATUS} = $terminal_info->{STATUS};
    $TERMINALS{DISTRICT_ID} = $terminal_info->{DISTRICT_ID};
    $TERMINALS{STREET_ID} = $terminal_info->{STREET_ID};
    $TERMINALS{LOCATION_ID} = $terminal_info->{LOCATION_ID};
  }

  if ($FORM{del}) {
    $Paysys->terminal_del({ ID => $FORM{del} });
    if (!$Paysys->{errno}) {
      $html->message('success', $lang{DELETED}, "$lang{TERMINAL} $lang{DELETED}");
    }
  }

  $TERMINALS{TERMINAL_TYPE} = $html->form_select('TERMINAL', {
    SELECTED    => $TERMINALS{TYPE},
    SEL_LIST    => $Paysys->terminal_type_list({ NAME => '_SHOW' }),
    SEL_KEY     => 'id',
    SEL_VALUE   => 'name',
    # ARRAY_NUM_ID => 1,
    NO_ID       => 1,
    SEL_OPTIONS => { '' => '--' },
    MAIN_MENU   => get_function_index('terminals_type_add'),
  });

  $TERMINALS{STATUS} = $html->form_select('STATUS', {
    SELECTED     => $TERMINALS{STATUS},
    SEL_ARRAY    => \@TERMINAL_STATUS,
    ARRAY_NUM_ID => 1,
    SEL_OPTIONS  => { '' => '--' },
    # MAIN_MENU    => get_function_index('terminals_type_add'),
  });

  use Address;
  my $Address = Address->new($db, $admin, \%conf);
  my %user_pi = ();
  if ($TERMINALS{DISTRICT_ID}) {
    $user_pi{ADDRESS_DISTRICT} = ($Address->district_info({ ID => $TERMINALS{DISTRICT_ID} }))->{NAME};
  }

  if ($TERMINALS{STREET_ID}) {
    $user_pi{ADDRESS_STREET} = ($Address->street_info({ ID => $TERMINALS{STREET_ID} }))->{NAME};
  }

  if ($TERMINALS{LOCATION_ID}) {
    $user_pi{ADDRESS_BUILD} = ($Address->build_info({ ID => $TERMINALS{LOCATION_ID} }))->{NUMBER};
  }

  $TERMINALS{ADRESS_FORM} = $html->tpl_show(
    templates('form_address_search'),
    {
      %user_pi,
      DISTRICT_ID => $TERMINALS{DISTRICT_ID},
      STREET_ID   => $TERMINALS{STREET_ID},
      LOCATION_ID => $TERMINALS{LOCATION_ID},
    },
    { OUTPUT2RETURN => 1 }
  );

  my @WEEKDAYS_WORK = ();
  if ($TERMINALS{WORK_DAYS}) {
    my $bin = sprintf("%b", int $TERMINALS{WORK_DAYS});
    @WEEKDAYS_WORK = split(//, $bin);
  }

  my $count = 1;
  foreach my $day (@WEEKDAYS) {
    next if (length $day > 4);
    my $checkbox = $html->form_input('WEEK_DAYS', $count, {
      class => 'list-checkbox',
      TYPE  => 'checkbox',
      STATE => $WEEKDAYS_WORK[$count - 1] ? $WEEKDAYS_WORK[$count - 1] : 0,
    }) . " " . $day;

    my $div_checkbox = $html->element('li', $checkbox, { class => 'list-group-item' });

    $TERMINALS{WEEK_DAYS1} .= $div_checkbox if ($count < 5);
    $TERMINALS{WEEK_DAYS2} .= $div_checkbox if ($count > 4);
    $count++;
  }

  $TERMINALS{START_WORK} = $html->form_timepicker('START_WORK', $TERMINALS{START_WORK});
  $TERMINALS{END_WORK} = $html->form_timepicker('END_WORK', $TERMINALS{END_WORK});

  $html->tpl_show(_include('paysys_terminals_add', 'Paysys'), \%TERMINALS);
  result_former({
    INPUT_DATA      => $Paysys,
    FUNCTION        => 'terminal_list',
    DEFAULT_FIELDS  => 'ID, TYPE, COMMENT, STATUS, DIS_NAME, ST_NAME, BD_NUMBER',
    FUNCTION_FIELDS => 'change,del',
    SKIP_USER_TITLE => 1,
    EXT_TITLES      => {
      id        => '#',
      type      => $lang{TYPE},
      comment   => $lang{COMMENTS},
      status    => $lang{STATUS},
      dis_name  => $lang{DISTRICT},
      st_name   => $lang{STREET},
      bd_number => $lang{BUILD},
    },
    TABLE           => {
      width   => '100%',
      caption => "$lang{TERMINALS}",
      qs      => $pages_qs,
      pages   => $Paysys->{TOTAL},
      ID      => 'PAYSYS_TERMINLS',
      MENU    => "$lang{ADD}:add_form=1&index=" . $index . ':add' . ";",
      EXPORT  => 1
    },
    MAKE_ROWS       => 1,
    TOTAL           => 1
  });

  return 1;
}

#**********************************************************
=head2 terminals_type_add() - add new terminal types

=cut
#**********************************************************
sub paysys_configure_terminals_type {
  my %TERMINALS;

  $TERMINALS{ACTION} = 'add';     # action on page
  $TERMINALS{BTN} = "$lang{ADD}"; # button name

  if ($FORM{ACTION} && $FORM{ACTION} eq 'add') {
    $Paysys->terminals_type_add({ %FORM });

    if (!$Paysys->{errno}) {
      $html->message('info', $lang{ADDED}, $lang{SUCCESS});

      if ($FORM{UPLOAD_FILE}) {
        upload_file($FORM{UPLOAD_FILE}, { PREFIX => '/terminals/',
          FILE_NAME                              => 'terminal_' . $Paysys->{INSERT_ID} . '.png', });
      }
    }
    else {
      $html->message('err', $lang{ERROR});
    }
  }
  elsif ($FORM{ACTION} && $FORM{ACTION} eq 'change') {
    $Paysys->terminal_type_change({ %FORM });

    if (!$Paysys->{errno}) {
      $html->message('info', $lang{CHANGED}, $lang{SUCCESS});
      if ($FORM{UPLOAD_FILE}) {
        upload_file($FORM{UPLOAD_FILE}, { PREFIX => '/terminals/',
          FILE_NAME                              => 'terminal_' . $FORM{ID} . '.png',
          REWRITE                                => 1 });
      }
    }
    else {
      $html->message('err', $lang{ERROR});
    }
  }

  if ($FORM{del}) {
    $Paysys->terminal_type_delete({ ID => $FORM{del} });

    if (!$Paysys->{errno}) {
      $html->message('info', $lang{DELETED}, $lang{SUCCESS});
      my $filename = "$conf{TPL_DIR}/terminals/terminal_$FORM{del}.png";
      if (-f $filename) {
        unlink("$filename") or die "Can't delete $filename:  $!\n";
      }
    }
    else {
      $html->message('err', $lang{ERROR});
    }
  }

  if ($FORM{chg}) {
    $TERMINALS{ACTION} = 'change';
    $TERMINALS{BTN} = "$lang{CHANGE}";

    my $type_info = $Paysys->terminal_type_info($FORM{chg});

    $TERMINALS{COMMENT} = $type_info->{COMMENT};
    $TERMINALS{NAME} = $type_info->{NAME};
    $TERMINALS{ID} = $FORM{chg}
  }

  $html->tpl_show(_include('paysys_terminals_type_add', 'Paysys'), \%TERMINALS);

  result_former(
    {
      INPUT_DATA      => $Paysys,
      FUNCTION        => 'terminal_type_list',
      DEFAULT_FIELDS  => 'ID, NAME, COMMENT',
      FUNCTION_FIELDS => 'change,del',
      SKIP_USER_TITLE => 1,
      EXT_TITLES      => {
        id      => '#',
        name    => $lang{NAME},
        comment => $lang{COMMENTS},

      },
      TABLE           => {
        width   => '100%',
        caption => "$lang{TERMINALS} $lang{TYPE}",
        qs      => $pages_qs,
        pages   => $Paysys->{TOTAL},
        ID      => 'PAYSYS_TERMINLS_TYPES',
        EXPORT  => 1
      },
      MAKE_ROWS       => 1,
      TOTAL           => 1
    }
  );

  return 1;
}

#**********************************************************
=head2 paysys_read_folder_systems($payment_system)

=cut
#**********************************************************
sub _configure_load_payment_module {
  my ($payment_system) = @_;

  if (!$payment_system) {
    return 0;
  }

  my ($paysys_name) = $payment_system =~ /(.+)\.pm/;

  my $require_module = "Paysys::systems::$paysys_name";

  eval {require "Paysys/systems/$payment_system";};

  if (!$@) {
    $require_module->import($payment_system);
  }
  else {
    print "Error loading\n";
    print $@;
  }

  return $require_module;
}

#**********************************************************
=head2 paysys_maps_($attr)

=cut
#**********************************************************
sub paysys_maps_new {

  use Paysys::Maps_info;
  my $Paysys_maps = Paysys::Maps_info->new($db, $admin, \%conf, { HTML => $html, LANG => \%lang });

  use Maps2::Maps_view;
  my $Maps_info = Maps2::Maps_view->new($db, $admin, \%conf, { HTML => $html, LANG => \%lang });

  return $Maps_info->show_map(\%FORM, {
    QUICK          => 1,
    DATA           => $Paysys_maps->paysys_terminals_show({ RETURN_OBJECTS => 1, ESCAPE => 1 }),
    DONE_DATA      => 1,
    HIDE_CONTROLS  => 1,
    NAVIGATION_BTN => 0,
    OUTPUT2RETURN  => 1,
    BUILD_ROUTE    => 1
  });
}

#**********************************************************
=head2 paysys_configure_main()

=cut
#**********************************************************
sub paysys_configure_main_new {
  # show form for paysys connection
  if ($FORM{add_form}) {
    my $btn_value = $lang{ADD};
    my $btn_name = 'add_paysys';
    my ($paysys_select, $json_list) = _paysys_select_systems();

    $html->tpl_show(
      _include('paysys_connect_system_new', 'Paysys'),
      {
        BTN_VALUE          => $btn_value,
        BTN_NAME           => $btn_name,
        PAYSYS_SELECT      => $paysys_select,
        JSON_LIST          => $json_list,
        PAYMENT_METHOD_SEL => _paysys_select_payment_method(),
      },
    );
  }

  # add system in paysys connection
  if ($FORM{add_paysys}) {
    if ($FORM{create_payment_method}) {
      require Payments;
      Payments->import();
      my $Payments = Payments->new($db, $admin, \%conf);

      $Payments->payment_type_add({
        NAME  => $FORM{NAME} || '',
        COLOR => '#000000'
      });
      $FORM{PAYMENT_METHOD} = $Payments->{INSERT_ID};
    }

    my $list = $Paysys->paysys_connect_system_list({
      SHOW_ALL_COLUMNS => '_SHOW',
      STATUS           => 1,
      COLS_NAME        => 1,
    });

    foreach my $item (@$list) {
      if ($item->{paysys_id} eq $FORM{PAYSYS_ID}){
        $html->message('error', $lang{ERROR}, $lang{EXIST});
        return 0;
      }
    }

    $Paysys->paysys_connect_system_add({
      PAYSYS_ID      => $FORM{PAYSYS_ID},
      NAME           => $FORM{NAME},
      MODULE         => $FORM{MODULE},
      PAYSYS_IP      => $FORM{IP},
      STATUS         => $FORM{STATUS},
      PAYMENT_METHOD => $FORM{PAYMENT_METHOD},
      PRIORITY       => $FORM{PRIORITY}
    });

    if (!_error_show($Paysys)) {
      $html->message('info', $lang{SUCCESS}, $lang{ADDED});
    }
  }

  # change %CONF params in db
  if ($FORM{change}) {
    if ($FORM{create_payment_method}) {
      require Payments;
      Payments->import();
      my $Payments = Payments->new($db, $admin, \%conf);

      $Payments->payment_type_add({
        NAME  => $FORM{NAME} || '',
        COLOR => '#000000'
      });
      $FORM{PAYMENT_METHOD} = $Payments->{INSERT_ID};
    }

    $Paysys->paysys_connect_system_change({
      %FORM,
      PAYSYS_IP => $FORM{IP},
    });
  }
  elsif ($FORM{del}) {
    $Paysys->paysys_connect_system_delete({
      ID => $FORM{del},
      %FORM
    });
    _error_show($Paysys);
  }

  if ($FORM{chg}) {
    my $btn_value = $lang{CHANGE};
    my $btn_name = 'change';

    my $connect_system_info = $Paysys->paysys_connect_system_info({
      ID               => $FORM{chg},
      SHOW_ALL_COLUMNS => 1,
      COLS_NAME        => 1,
      COLS_UPPER       => 1,
    });

    $html->tpl_show(
      _include('paysys_connect_system_new', 'Paysys'),
      {
        BTN_VALUE          => $btn_value,
        BTN_NAME           => $btn_name,
        ($connect_system_info && ref $connect_system_info eq "HASH" ? %$connect_system_info : ()),
        ACTIVE             => $connect_system_info->{status},
        IP                 => $connect_system_info->{paysys_ip},
        PRIORITY           => $connect_system_info->{priority},
        HIDE_SELECT        => 'hidden',
        ID                 => $FORM{chg},
        PAYMENT_METHOD_SEL => _paysys_select_payment_method({ PAYMENT_METHOD => $connect_system_info->{payment_method} }),
      },
    );
  }

  # table to show all systems in folder
  my $table_for_systems = $html->table(
    {
      caption    => "",
      width      => '100%',
      title      =>
        [ '#', $lang{PAY_SYSTEM}, $lang{MODULE}, $lang{VERSION}, $lang{STATUS}, 'IP', $lang{PRIORITY}, $lang{PERIODIC}, $lang{REPORT}, $lang{TEST}, '', '', '' ],
      MENU       => "$lang{ADD}:index=$index&add_form=1:add",
      DATA_TABLE => 1,
    }
  );

  my $systems = $Paysys->paysys_connect_system_list({
    SHOW_ALL_COLUMNS => 1,
    COLS_NAME        => 1,
    PAGE_ROWS        => 100,
  });

  foreach my $payment_system (@$systems) {

    my $require_module = _configure_load_payment_module($payment_system->{module});
    # check if module already on new verision and has get_settings sub
    if ($require_module->can('get_settings')) {
      my %settings = $require_module->get_settings();

      my $status = $payment_system->{status} || 0;
      my $paysys_name = $payment_system->{name} || '';
      my $id = $payment_system->{id} || 0;
      my $paysys_id = $payment_system->{paysys_id} || 0;
      my $paysys_ip = $payment_system->{paysys_ip} || '';
      my $priority = $payment_system->{priority} || 0;

      $status = (!($status) ? $html->color_mark("$lang{DISABLE}", 'danger') : $html->color_mark(
        "$lang{ENABLE}",
        'success'));

      my $merch_index = get_function_index('paysys_add_configure_groups');
      my $merchant_button = $html->button("$lang{MERCHANT_BUTTON}",
        "index=$merch_index&MODULE=$payment_system->{module}&PAYSYSTEM_ID=$paysys_id",
        { class => 'btn btn-primary btn-sm' });
      my $change_button = $html->button("$lang{CHANGE}",
        "index=$index&MODULE=$payment_system->{module}&chg=$id&PAYSYSTEM_ID=$paysys_id",
        { class => 'change' });
      my $delete_button = $html->button("$lang{DEL}",
        "index=$index&MODULE=$payment_system->{module}&del=$id&PAYSYSTEM_ID=$paysys_id",
        { class => 'del', MESSAGE => "$lang{DEL} $paysys_name", });
      my $test_button = '';
      if ($require_module->can('has_test') && $payment_system->{status} == 1) {
        my $test_index = get_function_index('paysys_main_test');
        $test_button = $html->button("$lang{START_PAYSYS_TEST}",
          "index=$test_index&MODULE=$payment_system->{module}&PAYSYSTEM_ID=$paysys_id",
          { class => 'btn btn-success btn-sm' });
      }
      elsif ($require_module->can('has_test')) {
        $test_button = $lang{PAYSYS_MODULE_NOT_TURNED_ON};
      }
      else {
        $test_button = $lang{NOT_EXIST};
      }

      $table_for_systems->addrow(
        $paysys_id,
        $paysys_name,
        $payment_system->{module},
        $settings{VERSION},
        $status,
        $paysys_ip,
        $priority,
        $require_module->can('periodic') ? $html->color_mark("$lang{YES}", 'success') : $html->color_mark("$lang{NO}", '#f04'),
        $require_module->can('report') ? $html->color_mark("$lang{YES}", 'success') : $html->color_mark("$lang{NO}", '#f04'),
        $test_button,
        $merchant_button,
        $change_button,
        $delete_button,
      );
    }

  }

  print $table_for_systems->show();

  return 1;
}

#**********************************************************
=head2 paysys_add_configure_groups()

  Arguments:
     -

  Returns:

=cut
#**********************************************************
sub paysys_add_configure_groups {
  if ($FORM{add_form}) {
    my $btn_value = $lang{ADD};
    my $btn_name = 'add_merchant';
    my ($paysys_select, $json_list) = _paysys_select_systems_new();

    $html->tpl_show(
      _include('paysys_merchant_config_add', 'Paysys'),
      {
        BTN_VALUE     => $btn_value,
        BTN_NAME      => $btn_name,
        PAYSYS_SELECT => $paysys_select,
        JSON_LIST     => $json_list
      },
    );
    return 1;
  }

  if ($FORM{add_merchant}) {
    if ($FORM{MERCHANT_NAME} && $FORM{SYSTEM_ID}) {
      $Paysys->merchant_settings_add({
        MERCHANT_NAME => $FORM{MERCHANT_NAME},
        SYSTEM_ID     => $FORM{SYSTEM_ID},
      });
      if (!$Paysys->{errno}) {
        my $merchant_id = $Paysys->{INSERT_ID};
        foreach my $key (keys %FORM) {
          next if (!$key);
          if ($key =~ /PAYSYS_/) {
            $FORM{$key} =~ s/[\n\r]//g;
            $FORM{$key} =~ s/"/\\"/g;
            $Paysys->merchant_params_add({
              PARAM       => $key,
              VALUE       => $FORM{$key},
              MERCHANT_ID => $merchant_id
            });
            if ($Paysys->{errno}) {
              return $html->message('err', $lang{ERROR}, "Error with $key : $FORM{$key}");
            }
          }
        }
      }
    }
    $html->message('info', $lang{ADDED});
  }
  elsif ($FORM{change}) {
    if ($FORM{MERCHANT_NAME} && $FORM{SYSTEM_ID}) {
      $Paysys->merchant_settings_change({
        ID            => $FORM{MERCHANT_ID},
        MERCHANT_NAME => $FORM{MERCHANT_NAME},
        SYSTEM_ID     => $FORM{SYSTEM_ID},
      });
      my $merchant_id = $FORM{MERCHANT_ID};
      if (!$Paysys->{errno}) {
        del_settings_to_config({ MERCHANT_ID => $merchant_id, DEL_ALL => 1 });
        $Paysys->merchant_params_delete({ MERCHANT_ID => $merchant_id });
        if (!$Paysys->{errno}) {
          foreach my $key (keys %FORM) {
            next if (!$key);
            if ($key =~ /PAYSYS_/) {
              $FORM{$key} =~ s/[\n\r]//g;
              $FORM{$key} =~ s/"/\\"/g;
              $Paysys->merchant_params_add({
                PARAM       => $key,
                VALUE       => $FORM{$key},
                MERCHANT_ID => $merchant_id
              });
              if ($Paysys->{errno}) {
                return $html->message('err', $lang{ERROR}, "Error with $key : $FORM{$key}");
              }
            }
          }
          add_settings_to_config({ MERCHANT_ID => $merchant_id, SYSTEM_ID => $FORM{SYSTEM_ID}, PARAMS_CHANGED => 1 });
          $html->message('info', $lang{CHANGED});
        }
        else {
          return $html->message('err', $lang{ERROR}, "Error : $Paysys->{errno}");
        }
      }
    }
  }
  elsif ($FORM{chgm}) {
    my $btn_value = $lang{CHANGE};
    my $btn_name = 'change';

    $FORM{merchant_name} =~ s/\\(['"]+)/$1/g;

    my ($paysys_select, $json_list) = _paysys_select_systems_new($FORM{system_name}, $FORM{chgm}, { change => 1 });

    $html->tpl_show(
      _include('paysys_merchant_config_add', 'Paysys'),
      {
        BTN_VALUE     => $btn_value,
        BTN_NAME      => $btn_name,
        PAYSYS_SELECT => $paysys_select,
        JSON_LIST     => $json_list,
        MERCHANT_NAME => $FORM{merchant_name} || '',
        HIDE_SELECT   => 'hidden',
        MERCHANT_ID   => $FORM{chgm} || ''
      },
    );
    return 1;
  }
  elsif ($FORM{del_merch}) {
    del_settings_to_config({ MERCHANT_ID => $FORM{del_merch}, DEL_ALL => 1 });
    $Paysys->merchant_settings_delete({ ID => $FORM{del_merch} });
    $Paysys->merchant_params_delete({ MERCHANT_ID => $FORM{del_merch} });
    if (!$Paysys->{errno}) {
      $html->message('info', $lang{DELETED});
    }
  }

  my $connected_payment_systems = $Paysys->paysys_connect_system_list({
    SHOW_ALL_COLUMNS => 1,
    STATUS           => 1,
    COLS_NAME        => 1,
  });

  if (ref $connected_payment_systems ne 'ARRAY' || !scalar(@$connected_payment_systems)) {
    $html->message('err', 'No payments system connected');
    return 1;
  }

  my $list = $Paysys->merchant_settings_list({
    ID             => '_SHOW',
    MERCHANT_NAME  => '_SHOW',
    SYSTEM_ID      => '_SHOW',
    PAYSYSTEM_NAME => '_SHOW',
    MODULE         => '_SHOW',
    COLS_NAME      => 1
  });

  my $table = $html->table(
    {
      ID         => 'MERCHANT_TABLE',
      caption    => $html->button("", "get_index=paysys_add_configure_groups&add_form=1&header=2",
        {
          LOAD_TO_MODAL => 1,
          class         => 'btn-sm fa fa-plus login_b text-success no-padding',
        }) . " $lang{PAYSYS_SETTINGS_FOR_MERCHANTS}",
      width      => '100%',
      title      =>
        [ '#', $lang{MERCHANT_NAME2}, $lang{PAY_SYSTEM}, $lang{MODULE}, "$lang{PARAMS} $lang{PAY_SYSTEM}", '', '' ],
      DATA_TABLE => 1,
    }
  );

  foreach my $item (@$list) {
    next if (!$item->{id});
    my $params = $Paysys->merchant_params_info({ MERCHANT_ID => $item->{id} });
    my $table_params = $html->table({
      width      => '100%',
      ID         => 'PAYSYS_MERCHANT_PARAMS',
      caption    => "$lang{PARAMS} $lang{PAY_SYSTEM}",
      HIDE_TABLE => 1
    });
    foreach my $param (keys %$params) {
      next if (!$param);
      $table_params->addrow($param, $params->{$param});
    }

    my $system_id = $item->{system_id} || $item->{paysys_id};
    my $merchant_name = $item->{merchant_name} || $item->{name};

    my $change_link = "get_index=paysys_add_configure_groups&chgm=$item->{id}&systen_id=$system_id&merchant_name=$merchant_name&"
      . "system_name=$item->{name}&header=2";

    $change_link =~ s/'/\%27/g;
    $table->addrow(
      $item->{id},
      $item->{merchant_name},
      $item->{name},
      $item->{module},
      $table_params->show(),
      $html->button("", $change_link,
        { LOAD_TO_MODAL => 1,
          ADD_ICON      => "fa fa-pencil",
          CONFIRM       => $lang{CONFIRM},
          ex_params => "data-tooltip='$lang{CHANGE}' data-tooltip-position='top'"
        }),
      $html->button($lang{DEL}, "index=$index&del_merch=$item->{id}", { MESSAGE => "$lang{DEL} $merchant_name?", class => 'del' })
    );
  }

  print $table->show();

  print paysys_configure_groups_new(\%FORM);
  print paysys_group_settings(\%FORM);

  return 1;
}

#**********************************************************
=head2 paysys_read_folder_systems_new()

=cut
#**********************************************************
sub _paysys_select_systems_new {
  my ($name, $id, $attr) = @_;
  my $systems = q{};
  my @array = ();
  my $list = q{};
  if ($attr->{change}) {
    $list = $Paysys->paysys_connect_system_list({
      SHOW_ALL_COLUMNS => 1,
      STATUS           => 1,
      COLS_NAME        => 1,
    });
  }
  else {
    $list = $Paysys->paysys_connect_system_list({
      SHOW_ALL_COLUMNS => 1,
      STATUS           => 1,
      COLS_NAME        => 1,
    });
  }

  my %HASH_TO_JSON = ();
  foreach my $system (@$list) {
    next if ($attr->{change} && $system->{name} ne $name);
    my $Module = _configure_load_payment_module($system->{module});
    if ($Module->can('get_settings')) {
      my %settings = $Module->get_settings();

      foreach my $key (keys %{$settings{CONF}}) {
        if (defined $name && $name ne '') {
          my $name_Up = uc($name);
          delete $settings{CONF}{$key} if $key =~ /_NAME_/;
          $key =~ s/_NAME_/_$name_Up\_/;
          $settings{CONF}{$key} = '';
        }
      }
      if ($attr->{change}) {
        my $params = $Paysys->merchant_params_info({ MERCHANT_ID => $id });
        @{$settings{CONF}}{keys %{$settings{CONF}}} = @{$params}{keys %{$settings{CONF}}};
      }
      $settings{SYSTEM_ID} = $system->{id};

      foreach my $key (keys %{$settings{CONF}}) {
        if ($settings{CONF}{$key}) {
          $settings{CONF}{$key} =~ s/\%/&#37;/g;
        }
      }
      $HASH_TO_JSON{$system->{name}} = \%settings;
    }
    if ($system->{name}) {
      push @array, $system->{name};
    }

  }

  $systems = \@array;

  my $json_list = JSON->new->utf8(0)->encode(\%HASH_TO_JSON);

  return $html->form_select('MODULE',
    {
      SELECTED    => $name || '',
      SEL_ARRAY   => $systems,
      NO_ID       => 1,
      SEL_OPTIONS => { '' => '--' },
    }), $json_list;
}

#**********************************************************
=head2 paysys_group_settings($attr)

  Arguments:
    $attr -

  Returns:

=cut
#**********************************************************
sub paysys_group_settings {
  my ($attr) = @_;
  if ($attr->{add_settings}) {
    _error_show($Paysys);
  }

  my $connected_payment_systems = $Paysys->paysys_connect_system_list({
    SHOW_ALL_COLUMNS => 1,
    STATUS           => 1,
    COLS_NAME        => 1,
  });

  if (ref $connected_payment_systems ne 'ARRAY' || !scalar(@$connected_payment_systems)) {
    $html->message('err', 'No payments system connected');
    return 1;
  }

  my $groups_list = $Users->groups_list({
    COLS_NAME       => 1,
    DISABLE_PAYSYS  => 0,
    GID             => '_SHOW',
    NAME            => '_SHOW',
    DESCR           => '_SHOW',
    ALLOW_CREDIT    => '_SHOW',
    DISABLE_PAYSYS  => '_SHOW',
    DISABLE_CHG_TP  => '_SHOW',
    USERS_COUNT     => '_SHOW',
  });

  my @connected_payment_systems = ('#', $lang{GROUPS});
  foreach my $system (@$connected_payment_systems) {
    my $Module = _configure_load_payment_module($system->{module});
    if ($Module->can('user_portal') || $Module->can('user_portal_special')) {
      push(@connected_payment_systems, $system->{name});
    }
  }

  # Show systems in user portal
  my $table_UsPor = $html->table(
    {
      ID         => 'GROUPS_USER_PORTAL_TABLE',
      caption    => "$lang{SHOW_PAYSYSTEM_IN_USER_PORTAL}",
      width      => '100%',
      title      => \@connected_payment_systems,
      rowcolor   => 'odd marked',
      DATA_TABLE => 1
    }
  );

  my $list_settings = $Paysys->groups_settings_list({
    GID       => '_SHOW',
    PAYSYS_ID => '_SHOW',
    COLS_NAME => 1,
    PAGE_ROWS => 99999,
  });

  my %groups_settings = ();
  foreach my $gid_settings (@$list_settings) {
    $groups_settings{"SETTINGS_$gid_settings->{gid}_$gid_settings->{paysys_id}"} = 1;

  }
  # form rows for table
  foreach my $group (@$groups_list) {
    my @rows;
    next if $group->{disable_paysys} == 1;

    foreach my $system (@$connected_payment_systems) {
      my $Module = _configure_load_payment_module($system->{module});
      if ($Module->can('user_portal') || $Module->can('user_portal_special')) {
        my $input_name = "SETTINGS_$group->{gid}_$system->{paysys_id}";
        if ($attr->{add_settings}) {
          if (defined $attr->{$input_name} && $attr->{$input_name} == 1) {
            $Paysys->groups_settings_add_user_portal({
              GID       => $group->{gid},
              PAYSYS_ID => $system->{paysys_id},
            });
          $groups_settings{$input_name} = 1 if (!$Paysys->{errno});
          }
          if (defined $attr->{$input_name} && $attr->{$input_name} == 0) {
            $Paysys->groups_settings_del({
              GID       => $group->{gid},
              PAYSYS_ID => $system->{paysys_id},
            });
            $groups_settings{$input_name} = 0 if (!$Paysys->{errno});
          }
        }
        my $checkbox = $html->form_input("$input_name", "1",
          { TYPE => 'checkbox', STATE => (($groups_settings{$input_name}) ? 'checked' : ''), EX_PARAMS => 'data-toggle="toggle"' });
        push(@rows, '&nbsp;' . $checkbox);
      }
    }
    $table_UsPor->addrow($group->{gid}, $group->{name}, @rows);
  }
  $table_UsPor->addfooter($html->form_input('add_settings', $lang{SAVE}, { TYPE => 'submit' }));

  $html->tpl_show(
    _include('paysys_group_settings', 'Paysys'),
  );

  return $html->form_main(
    {
      CONTENT => $table_UsPor->show(),
      HIDDEN  => {
        index => "$index",
      },
      NAME    => 'PAYSYS_GROUPS_SETTINGS'
    }
  );
}

#**********************************************************
=head2 paysys_configure_groups_new($attr)

  Arguments:
    $attr -

  Returns:

=cut
#**********************************************************
sub paysys_configure_groups_new {

  if (defined $FORM{chg}) {
    return paysys_merchant_select(\%FORM);
  }

  if ($FORM{save_merch_gr}) {
    foreach my $key (keys %FORM) {
      next if (!$key);
      if ($key =~ /SETTINGS_/) {
        my (undef, $gid, $system_id) = split('_', $key);
        $Paysys->paysys_merchant_to_groups_delete({ PAYSYS_ID => $system_id, GID => (defined $gid && $gid == 0) ? '0' : $gid });
        next if ($FORM{"SETTINGS_$gid" . "_$system_id"} eq '');
        $Paysys->paysys_merchant_to_groups_add({
          GID       => $gid,
          PAYSYS_ID => $system_id,
          MERCH_ID  => $FORM{"SETTINGS_$gid" . "_$system_id"}
        });
        if ($Paysys->{errno}) {
          return $html->message('err', $lang{ERROR}, "Error with $key : $FORM{$key}");
        }
        else {
          add_settings_to_config({
            MERCHANT_ID => $FORM{"SETTINGS_$gid" . "_$system_id"},
            GID         => $gid
          });
        }
      }
    }
  }
  if (defined $FORM{clear_set}) {
    my $_list = $Paysys->merchant_for_group_list({
      PAYSYS_ID => '_SHOW',
      MERCH_ID  => '_SHOW',
      GID       => "$FORM{clear_set}",
      LIST2HASH => 'paysys_id,merch_id'
    });

    foreach my $key (keys %{$_list}) {
      next if (!$key);
      del_settings_to_config({ MERCHANT_ID => $_list->{$key}, GID => (defined $FORM{clear_set} && $FORM{clear_set} == 0) ? '0' : $FORM{clear_set} });
      $Paysys->paysys_merchant_to_groups_delete({ PAYSYS_ID => $key, GID => (defined $FORM{clear_set} && $FORM{clear_set} == 0) ? '0' : $FORM{clear_set} });
    }
    $html->message('info', $lang{DELETED});
  }

  my $connected_payment_systems = $Paysys->paysys_connect_system_list({
    SHOW_ALL_COLUMNS => 1,
    STATUS           => 1,
    COLS_NAME        => 1,
  });

  if (ref $connected_payment_systems ne 'ARRAY' || !scalar(@$connected_payment_systems)) {
    $html->message('err', 'No payments system connected');
    return 1;
  }

  my $groups_list = $Users->groups_list({
    COLS_NAME      => 1,
    DISABLE_PAYSYS => 0,
          GID             => '_SHOW',
      NAME            => '_SHOW',
      DESCR           => '_SHOW',
      ALLOW_CREDIT    => '_SHOW',
      DISABLE_PAYSYS  => '_SHOW',
      DISABLE_CHG_TP  => '_SHOW',
      USERS_COUNT     => '_SHOW',
  });

  push(@$groups_list,
    {
      'allow_credit'   => '0',
      'descr'          => 'default',
      'disable_chg_tp' => '0',
      'disable_paysys' => '0',
      'domain_id'      => '0',
      'gid'            => '0',
      'name'           => 'default',
      'users_count'    => '0'
    });

  my @connected_payment_systems = ('#', $lang{GROUPS});
  foreach my $system (@$connected_payment_systems) {
    push(@connected_payment_systems, $system->{name});
  }
  push(@connected_payment_systems, '', '');
  # Show systems in user portal
  my $table = $html->table(
    {
      ID         => 'GROUPS_GROUP_SETTINGS',
      caption    => "$lang{SELECT_MERCHANT_FOR_GROUP}",
      width      => '100%',
      title      => \@connected_payment_systems,
      DATA_TABLE => 1
    }
  );

  my $list = $Paysys->paysys_merchant_to_groups_info({ COLS_NAME => 1 });

  my %settings_hash = ();
  foreach my $item (@$list) {
    next unless (defined($item->{gid}) && $item->{paysys_id});
    if ($item->{merchant_name}) {
      $settings_hash{$item->{gid}}{$item->{paysys_id}} = $item->{merchant_name};
    }
    else {
      $settings_hash{$item->{gid}}{$item->{paysys_id}} = $item->{name};
    }
  }

  foreach my $group (@$groups_list) {
    my @rows;
    next if $group->{disable_paysys} == 1;
    foreach my $system (@$connected_payment_systems) {
      if (exists $settings_hash{$group->{gid}}{$system->{id}}) {
        push(@rows, "$settings_hash{$group->{gid}}{$system->{id}}");
      }
      else {
        push(@rows, "$lang{NOT_EXIST}");
      }
    }
    $table->addrow(
      $group->{gid},
      $group->{name},
      @rows,
      $html->button("", "get_index=paysys_configure_groups_new&header=2&chg=$group->{gid}",
        { LOAD_TO_MODAL => 1,
          ADD_ICON      => "fa fa-pencil",
          CONFIRM       => $lang{CONFIRM},
          ex_params     => "data-tooltip='$lang{CHANGE}' data-tooltip-position='top'"
        }),
      $html->button($lang{DEL}, "index=$index&clear_set=$group->{gid}", { MESSAGE => "$lang{DEL} $lang{FOR} $group->{name}?", class => 'del' }));
  }

  return $html->form_main(
    {
      CONTENT => $table->show(),
      HIDDEN  => {
        index => "$index",
      },
      NAME    => 'PAYSYS_GROUP_SETTINGS'
    }
  );
}

#**********************************************************
=head2 paysys_merchant_select()

  Arguments:
     -

  Returns:

=cut
#**********************************************************
sub paysys_merchant_select {
  my ($attr) = @_;
  my $group = ();
  if (defined $attr->{chg} && $attr->{chg} != 0) {
    $group = $Users->groups_list({
            GID             => '_SHOW',
      NAME            => '_SHOW',
      DESCR           => '_SHOW',
      ALLOW_CREDIT    => '_SHOW',
      DISABLE_PAYSYS  => '_SHOW',
      DISABLE_CHG_TP  => '_SHOW',
      USERS_COUNT     => '_SHOW',
      GID       => $attr->{chg},
      COLS_NAME => 1,
    });
    $group = $group->[0];
  }
  else {
    $group->{name} = 'default';
  }

  my $connected_payment_systems = $Paysys->paysys_connect_system_list({
    SHOW_ALL_COLUMNS => 1,
    STATUS           => 1,
    COLS_NAME        => 1,
  });

  my $list = $Paysys->merchant_settings_list({
    ID             => '_SHOW',
    MERCHANT_NAME  => '_SHOW',
    SYSTEM_ID      => '_SHOW',
    PAYSYSTEM_NAME => '_SHOW',
    MODULE         => '_SHOW',
    COLS_NAME      => 1
  });
  my $paysystem_sel = qq{};
  foreach my $system (@$connected_payment_systems) {
    next if (!$system);
    my %merch_select_hash = ();
    my $select_name = qq{};
    my $selected_val = qq{};
    my $selected_values = $Paysys->merchant_for_group_list({
      GID       => $attr->{chg},
      PAYSYS_ID => $system->{id},
      MERCH_ID  => '_SHOW',
      LIST2HASH => 'paysys_id,merch_id'
    });

    foreach my $merch (@$list) {
      if ($merch->{system_id} eq $system->{id}) {
        $selected_val = $selected_values->{$merch->{system_id}} || '';
        $select_name = qq{SETTINGS_$attr->{chg}_$system->{id}};
        $merch_select_hash{$merch->{id}} = $merch->{merchant_name};
      }
    }

    $paysystem_sel .= $html->tpl_show(_include('paysys_select_for_group', 'Paysys'), {
      LABEL_NAME      => $system->{name},
      MERCHANT_SELECT => $html->form_select(
        $select_name,
        {
          SELECTED => $selected_val,
          SEL_HASH => { '' => '', %merch_select_hash },
          NO_ID    => 1
        }
      )
    }, { OUTPUT2RETURN => 1 });
  }

  $html->tpl_show(_include('paysys_merchants_for_groups', 'Paysys'), {
    GROUP_NAME    => $group->{name},
    GROUP_ID      => $attr->{chg},
    PAYSYSTEM_SEL => $paysystem_sel,
    INDEX         => get_function_index('paysys_add_configure_groups')
  });
  return 1;
}

#**********************************************************s
=head2 add_settings_to_config($attr)

  Arguments:
    $attr -
      SYSTEM_ID
      PARAMS_CHANGED
      MERCHANT_ID

  Returns:

=cut
#**********************************************************
sub add_settings_to_config {
  my ($attr) = @_;

  my $Config = Conf->new($db, $admin, \%conf);
  my $gr_list = ();

  if ($attr->{SYSTEM_ID} && $attr->{PARAMS_CHANGED}) {
    $gr_list = $Paysys->merchant_for_group_list({
      PAYSYS_ID => $attr->{SYSTEM_ID},
      MERCH_ID  => $attr->{MERCHANT_ID},
      GID       => '_SHOW',
      LIST2HASH => 'gid,merch_id'
    });

    while (my ($k, $v) = each(%{$gr_list})) {
      add_settings_to_config({
        MERCHANT_ID => $v,
        GID         => $k
      });
    }
    return 1;
  }

  my $list = $Paysys->merchant_params_info({ MERCHANT_ID => $attr->{MERCHANT_ID} });

  foreach my $key (keys %{$list}) {
    if (defined $attr->{GID} && $attr->{GID} != 0) {
      #print $key . "_$attr->{GID}" .'<br>';
      $Config->config_add({
        PARAM   => $key . "_$attr->{GID}",
        VALUE   => $list->{$key},
        REPLACE => 1
      });
    }
    else {
      $Config->config_add({
        PARAM   => $key,
        VALUE   => $list->{$key},
        REPLACE => 1
      });
    }
  }

  return 1;
}

#**********************************************************
=head2 del_settings_to_config($attr)

  Arguments:
    $attr -
      GID
      MERCHANT_ID
      DEL_ALL

  Returns:

=cut
#**********************************************************
sub del_settings_to_config {
  my ($attr) = @_;
  my $Config = Conf->new($db, $admin, \%conf);

  my $list = $Paysys->merchant_params_info({ MERCHANT_ID => $attr->{MERCHANT_ID} });

  foreach my $key (keys %{$list}) {
    if (defined $attr->{GID} && $attr->{GID} != 0) {
      $Config->config_del($key . "_$attr->{GID}");
    }
    else {
      $Config->config_del($key);
    }
  }

  return 1;
}

1;