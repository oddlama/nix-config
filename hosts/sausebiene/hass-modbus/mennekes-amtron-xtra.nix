{ globals, ... }:
{
  services.home-assistant.config = {
    recorder.exclude.entities = [ "sensor.amtron_registers" ];
    logbook.exclude.entities = [ "sensor.amtron_registers" ];
    influxdb.exclude.entities = [ "sensor.amtron_registers" ];

    modbus = [
      {
        delay = 1;
        host = globals.net.home-lan.vlans.devices.hosts.wallbox.ipv4;
        name = "Amtron Xtra 22 C2";
        port = 502;
        retries = 1;
        retry_on_empty = true;
        sensors = [
          {
            address = 768;
            count = 38;
            data_type = "custom";
            input_type = "input";
            lazy_error_count = 1;
            name = "Amtron Registers";
            precision = 0;
            scan_interval = 120;
            slave = 255;
            structure = ">2h15H22B10H";
          }
          {
            address = 1024;
            count = 1;
            data_type = "uint16";
            device_class = "current";
            input_type = "holding";
            name = "Amtron Current Limitation";
            slave = 255;
            unique_id = "amtron_current_limitation";
            unit_of_measurement = "A";
          }
          {
            address = 1025;
            count = 1;
            data_type = "uint16";
            input_type = "holding";
            name = "Amtron Change Charge State";
            slave = 255;
            unique_id = "amtron_change_charge_state";
          }
        ];
        timeout = 10;
        type = "tcp";
      }
    ];
    template = [
      {
        sensor = [
          {
            availability = "{{ has_value('sensor.amtron_registers') }}";
            device_class = "temperature";
            name = "Amtron HMI Temp Internal";
            state = "{{ states('sensor.amtron_registers').split(',')[0] }}";
            state_class = "measurement";
            unique_id = "amtron_hmi_temp_int";
            unit_of_measurement = "°C";
          }
        ];
      }
      {
        sensor = [
          {
            availability = "{{ has_value('sensor.amtron_registers') }}";
            device_class = "temperature";
            name = "Amtron HMI Temp External";
            state = "{{ states('sensor.amtron_registers').split(',')[1] }}";
            state_class = "measurement";
            unique_id = "amtron_hmi_temp_ext";
            unit_of_measurement = "°C";
          }
        ];
      }
      {
        sensor = [
          {
            availability = "{{ has_value('sensor.amtron_registers') }}";
            name = "Amtron CP State";
            state = ''
              {% set mapper = {
                '0' : 'illegal/bad',
                '1' : 'A1 - Not connected',
                '2' : 'A2 - Not connected',
                '3' : 'B1 - Connected',
                '4' : 'B2 - Connected',
                '5' : 'C1 - Charging',
                '6' : 'C2 - Charging',
                '7' : 'D1 - Charging with Ventilation',
                '8' : 'D2 - Charging with Ventilation' } %}
              {% set state = states('sensor.amtron_registers').split(',')[2] %}
              {{ mapper[state] if state in mapper else 'Unknown' }}
            '';
            unique_id = "amtron_cp_state";
          }
        ];
      }
      {
        sensor = [
          {
            availability = "{{ has_value('sensor.amtron_registers') }}";
            name = "Amtron PP State";
            state = ''
              {% set mapper = {
                '0' : 'illegal/bad',
                '1' : 'Open',
                '2' : '13A',
                '3' : '20A',
                '4' : '32A' } %}
              {% set state = states('sensor.amtron_registers').split(',')[3] %}
              {{ mapper[state] if state in mapper else 'Unknown' }}
            '';
            unique_id = "amtron_pp_state";
          }
        ];
      }
      {
        sensor = [
          {
            availability = "{{ has_value('sensor.amtron_registers') }}";
            name = "Amtron State";
            state = ''
              {% set mapper = {
                '0' : 'Idle',
                '1' : 'Standby Authorize',
                '2' : 'Standby Connect',
                '3' : 'Charging',
                '4' : 'Paused',
                '5' : 'Terminated',
                '6' : 'Error' } %}
              {% set state = states('sensor.amtron_registers').split(',')[5] %}
              {{ mapper[state] if state in mapper else 'Unknown' }}
            '';
            unique_id = "amtron_state";
          }
        ];
      }
      {
        sensor = [
          {
            availability = "{{ has_value('sensor.amtron_registers') }}";
            name = "Amtron Phases";
            state = ''
              {% set mapper = {
                '0' : 'Unknown',
                '1' : '1 Phase',
                '3' : '3 Phases' } %}
              {% set state = states('sensor.amtron_registers').split(',')[8] %}
              {{ mapper[state] if state in mapper else 'Unknown' }}
            '';
            unique_id = "amtron_phases";
          }
        ];
      }
      {
        sensor = [
          {
            availability = "{{ has_value('sensor.amtron_registers') }}";
            device_class = "current";
            name = "Amtron Rated Current";
            state = "{{ states('sensor.amtron_registers').split(',')[9] }}";
            state_class = "measurement";
            unique_id = "amtron_rated_current";
            unit_of_measurement = "A";
          }
        ];
      }
      {
        sensor = [
          {
            availability = "{{ has_value('sensor.amtron_registers') }}";
            device_class = "current";
            name = "Amtron Installation Current";
            state = "{{ states('sensor.amtron_registers').split(',')[10] }}";
            state_class = "measurement";
            unique_id = "amtron_installation_current";
            unit_of_measurement = "A";
          }
        ];
      }
      {
        sensor = [
          {
            availability = "{{ has_value('sensor.amtron_registers') }}";
            name = "Amtron Serial Number";
            state = "{% set sn = (states('sensor.amtron_registers').split(',')[11]|int + states('sensor.amtron_registers').split(',')[12]|int * 65536) | string %} 135{{ sn[:4] }}.{{ sn[4:] }}";
            unique_id = "amtron_serial_number";
          }
        ];
      }
      {
        sensor = [
          {
            availability = "{{ has_value('sensor.amtron_registers') }}";
            device_class = "energy";
            name = "Amtron Energy";
            state = "{{ states('sensor.amtron_registers').split(',')[13]|int + states('sensor.amtron_registers').split(',')[14]|int * 65536 }}";
            state_class = "total_increasing";
            unique_id = "amtron_energy";
            unit_of_measurement = "Wh";
          }
        ];
      }
      {
        sensor = [
          {
            availability = "{{ has_value('sensor.amtron_registers') }}";
            device_class = "power";
            name = "Amtron Power";
            state = "{{ states('sensor.amtron_registers').split(',')[15]|int + states('sensor.amtron_registers').split(',')[16]|int * 65536 }}";
            state_class = "measurement";
            unique_id = "amtron_power";
            unit_of_measurement = "W";
          }
        ];
      }
      {
        sensor = [
          {
            availability = "{{ has_value('sensor.amtron_registers') }}";
            name = "Amtron Wallbox Name";
            state = ''
              {% set ns = namespace(name = ''') -%}
              {% set input = states('sensor.amtron_registers').split(',')[17:40] -%}
              {% for i in range(0,11) -%}
                {% set ns.name = ns.name ~ \"%c\"%input[i*2+1]|int ~ \"%c\"%input[i*2]|int -%}
              {% endfor %}
              {{ ns.name.replace('\\x00',''') }}
            '';
            unique_id = "amtron_wallbox_name";
          }
        ];
      }
      {
        sensor = [
          {
            availability = "{{ has_value('sensor.amtron_registers') }}";
            device_class = "current";
            name = "Amtron Max Current T1";
            state = "{{ states('sensor.amtron_registers').split(',')[40] }}";
            state_class = "measurement";
            unique_id = "amtron_max_current_t1";
            unit_of_measurement = "A";
          }
        ];
      }
      {
        sensor = [
          {
            availability = "{{ has_value('sensor.amtron_registers') }}";
            device_class = "current";
            name = "Amtron Max Current T2";
            state = "{{ states('sensor.amtron_registers').split(',')[44] }}";
            state_class = "measurement";
            unique_id = "amtron_max_current_t2";
            unit_of_measurement = "A";
          }
        ];
      }
    ];
  };
}
