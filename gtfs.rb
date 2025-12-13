require 'date'
require 'yaml'
require 'digest/sha1'
require 'csv'
require 'json'

# sudo gem install nokogiri
require 'nokogiri'

class GovRoGTFSConverter
    @@timetables_start_date = nil
    @@timetables_end_date = nil

    def self.parse_and_save_for_dates(timetables_start_date, timetables_end_date)
        print "START: #{Time.now.strftime("%H:%M:%S")}\n"
        
        if timetables_start_date.is_a? String
            timetables_start_date = Date.parse(timetables_start_date)
            timetables_end_date = Date.parse(timetables_end_date)
        end

        @@timetables_start_date = timetables_start_date
        @@timetables_end_date = timetables_end_date

        trips_data = self::trips_data_from_xml

        gtfs_data = {}
        gtfs_data['agency'] = self::gtfs_data_agency
        gtfs_data['calendar'] = self::gtfs_data_calendar_from_trips_data(trips_data)
        gtfs_data['calendar_dates'] = self::gtfs_data_calendar_dates(gtfs_data['calendar'])
        gtfs_data['routes'] = self::gtfs_data_routes_from_trips_data(trips_data)
        gtfs_data['stops'] = self::gtfs_data_stops_from_trips_data(trips_data)
        gtfs_data['stop_times'] = self::gtfs_data_stop_times_from_trips_data(trips_data)
        gtfs_data['trips'] = trips_data

        self.write_gtfs_data(gtfs_data)

        print "DONE: #{Time.now.strftime("%H:%M:%S")}\n"
    end

    def self.trips_data_from_xml
        trips_data = []
        Dir["#{APP_PATH}/data.gov.ro/*.xml"].each do |file_path|
            print "Parsing #{file_path}\n"
            trips_data += self::trips_data_from_file(file_path)
        end

        return trips_data
    end

    def self.trips_data_from_file(file_path)
        trips_data = []

        trip_ids = {}
        
        settings = YAML.load_file("#{APP_PATH}/settings.yml")
        agency_rows = self::gtfs_data_agency()
        agency_map = {}
        agency_rows.each do |agency_row|
            agency_id = agency_row['agency_id'].to_s
            agency_map[agency_id] = agency_row
        end

        file_content = IO.read(file_path)
        doc = Nokogiri::XML(file_content)  
        doc.xpath('/XmlIf/XmlMts/Mt/Trenuri/Tren').each_with_index do |trip_row, k_train|
            trip_id = trip_row.attr('Numar')
            trip_type = trip_row.attr('CategorieTren')

            if trip_ids[trip_id]
                print "ERROR trip_id #{trip_id} exists already in #{file_path}\n"
                next
            end

            # Some XMLs have empty Operator, i.e. Astra.
            agency_id = trip_row.attr('Operator')
            if agency_map[agency_id].nil?
                settings['fuzzy_agency_matching'].each do |filename_keywords, fuzzy_agency_id|
                    if file_path.include? filename_keywords
                        agency_id = fuzzy_agency_id
                        break
                    end
                end
            end

            if agency_map[agency_id].nil?
                print "BROKEN agency_id #{agency_id} for trip #{trip_id} in #{file_path}\n"
                exit
            end

            trip_data = {
                'trip_id' => trip_id,
                'agency_id' => agency_id,
                'trip_short_name' => trip_id,
                'train_type_name' => trip_type,
                'stops_data' => self::trip_stops_data_for_xml_row(trip_row, trip_id),
                'calendar_data' => self::trip_calendar_data_for_xml_row(trip_row),
            }

            trip_ids[trip_id] = trip_data

            trips_data.push(trip_data)
        end

        return trips_data
    end

    def self.trip_calendar_data_for_xml_row(trip_row)
        trip_calendar_rows = []

        calendar_rows = trip_row.xpath('RestrictiiTren/CalendarTren')
        if calendar_rows.size == 0
            # Assuming that trips without 'RestrictiiTren' run all days of week
            trip_calendar_row = {
                'start_date' => @@timetables_start_date,
                'end_date' => @@timetables_end_date,
                'week_pattern' => '1111111',
            }
            trip_calendar_rows.push(trip_calendar_row)
        else
            calendar_rows.each do |calendar_row|
                start_date = Date.parse(calendar_row.attr('DeLa'))
                end_date = Date.parse(calendar_row.attr('PinaLa'))

                # index 0 is Saturday
                week_pattern = calendar_row.attr('Zile').to_i(10).to_s(2).split('').last(7).join('')
                # gov.ro has first day of week Saturday 
                #    and for Ruby's %w is Sunday 
                # => so we need to do some magic to the week_pattern
                week_pattern = "#{week_pattern[1..6]}#{week_pattern[0]}"

                trip_calendar_row = {
                    'start_date' => start_date,
                    'end_date' => end_date,
                    'week_pattern' => week_pattern,
                }
                trip_calendar_rows.push(trip_calendar_row)
            end
        end

        return trip_calendar_rows
    end

    def self.trip_stops_data_for_xml_row(trip_row, trip_id)
        trip_stop_rows = []

        stop_arrival_seconds = -1
        total_distance = 0

        station_rows = trip_row.xpath('Trase/Trasa/ElementTrasa')
        station_rows.each_with_index do |station_row, k|
            is_first_stop = k == 0
            is_last_stop = k == (station_rows.size - 1)

            stop_id = station_row.attr('CodStaOrigine')
            stop_name = station_row.attr('DenStaOrigine')
            stop_departure_seconds = station_row.attr('OraP').to_i
            if is_last_stop
                stop_departure_seconds = -1
            end

            stop_next_id = station_row.attr('CodStaDest')
            stop_next_arrival_seconds = station_row.attr('OraS').to_i

            if !is_last_stop && (stop_id == stop_next_id)
                print "ERROR / IGNORE: found id for consecutive stops: #{stop_name}(#{stop_id}) =>  -- Trip_id: #{trip_id}\n"
                next
            end

            trip_stop_row = {
                'trip_id' => trip_id,
                'stop_id' => stop_id,
                'stop_name' => stop_name,
                'stop_arrival_seconds' => stop_arrival_seconds,
                'stop_departure_seconds' => stop_departure_seconds,
                'total_distance' => total_distance,
            }
            trip_stop_rows.push(trip_stop_row)

            stop_arrival_seconds = stop_next_arrival_seconds
            total_distance += (station_row.attr('Km').to_i / 1000).to_i
        end

        # Detect "midnight" vehicles
        time_add_1_DAY = nil
        trip_stop_rows.each_with_index do |stop_data, k|
            is_not_first_stop = k > 0
            is_not_last_stop = k < (trip_stop_rows.size - 1)

            if time_add_1_DAY.nil? && is_not_first_stop
                stop_previous_data = trip_stop_rows[k - 1]
                if stop_previous_data['stop_departure_seconds'] > stop_data['stop_arrival_seconds']
                    time_add_1_DAY = true
                end
            end
            stop_data['arrival_time'] = self::seconds_to_string(stop_data['stop_arrival_seconds'], time_add_1_DAY)


            if time_add_1_DAY.nil? && is_not_last_stop && (stop_data['stop_arrival_seconds'] > stop_data['stop_departure_seconds'])
                time_add_1_DAY = true
            end
            stop_data['departure_time'] = self::seconds_to_string(stop_data['stop_departure_seconds'], time_add_1_DAY)
        end

        # Actually the ElementTrasa nodes contain all the stops in between no matter if the train stops or not there
        # => we remove all the stops in which the train stops for ... 0 seconds, so not at all
        trip_stop_rows = trip_stop_rows.select{ |stop_data| stop_data['arrival_time'] != stop_data['departure_time'] }

        return trip_stop_rows
    end

    def self.seconds_to_string(total_seconds, add_one_day)
        if total_seconds == -1
            return nil
        end

        if add_one_day
            total_seconds += 24 * 3600
        end

        seconds = total_seconds % 60
        minutes = (total_seconds / 60) % 60
        hours = total_seconds / (60 * 60)
    
        return format("%02d:%02d:%02d", hours, minutes, seconds)
    end

    def self.gtfs_data_agency
        settings = YAML.load_file("#{APP_PATH}/settings.yml")
        return settings['agency_mapping']
    end

    def self.gtfs_data_calendar_from_trips_data(trips_data)
        calendar_map = {}
        calendar_service_id = 1

        week_day_ids = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday']

        trips_data.each do |trip_data|
            calendar_key = Digest::SHA1.hexdigest(trip_data['calendar_data'].join)
            
            calendar_row = calendar_map[calendar_key]
            if calendar_row.nil?
                week_pattern = trip_data['calendar_data'].first['week_pattern']
                day_bits = self::day_bits_for_calendar_row(trip_data['calendar_data'])
                calendar_row = {
                    'service_id' => calendar_service_id,
                    'day_bits' => day_bits,
                    'week_pattern' => week_pattern,
                    'start_date' => @@timetables_start_date.strftime("%Y%m%d"),
                    'end_date' => @@timetables_end_date.strftime("%Y%m%d"),
                }
                
                calendar_row['calendar_dates'] = self::calendar_dates_for_calendar_row(calendar_row)
                
                week_day_ids.each_with_index do |day_column, day_index|
                    calendar_row[day_column] = week_pattern[day_index]
                end

                calendar_map[calendar_key] = calendar_row
                calendar_service_id += 1
            end

            trip_data['service_id'] = calendar_row['service_id']
        end
        
        return calendar_map.values
    end

    def self.day_bits_for_calendar_row(calendar_rows)
        day_bits = []
        
        timetable_date = @@timetables_start_date
        loop do
            day_bit = 0

            calendar_rows.each do |calendar_row|
                if timetable_date < calendar_row['start_date']
                    next
                end

                if timetable_date > calendar_row['end_date']
                    next
                end

                day_id = timetable_date.strftime("%w").to_i
                day_bit = calendar_row['week_pattern'][day_id].to_i
            end

            day_bits.push(day_bit)

            timetable_date += 1
            break if timetable_date > @@timetables_end_date
        end

        return day_bits.join('')
    end

    def self.calendar_dates_for_calendar_row(calendar_row)
        calendar_dates_rows = []

        timetable_date = @@timetables_start_date
        loop do
            day_index = (timetable_date - @@timetables_start_date).to_i
            day_bit_actual = calendar_row['day_bits'][day_index]

            day_week_id = timetable_date.strftime("%w").to_i
            day_bit_expected = calendar_row['week_pattern'][day_week_id]

            if day_bit_actual != day_bit_expected
                exception_type = nil
                # A value of 1 indicates that service has been added for the specified date.
                if (day_bit_expected == '0') && (day_bit_actual == '1')
                    exception_type = 1
                end

                # A value of 2 indicates that service has been removed for the specified date.
                if (day_bit_expected == '1') && (day_bit_actual == '0')
                    exception_type = 2
                end

                if exception_type.nil?
                    print "WTF\n"
                    exit
                end

                calendar_dates_row = {
                    'service_id' => calendar_row['service_id'],
                    'date' => timetable_date.strftime("%Y%m%d"),
                    'exception_type' => exception_type,
                }
                calendar_dates_rows.push(calendar_dates_row)
            end

            timetable_date += 1
            break if timetable_date > @@timetables_end_date
        end

        return calendar_dates_rows
    end

    def self.gtfs_data_calendar_dates(calendar_rows)
        calendar_dates_rows = []

        calendar_rows.each do |calendar_row|
            if calendar_row['calendar_dates'].size == 0
                next
            end

            calendar_dates_rows += calendar_row['calendar_dates']
        end

        return calendar_dates_rows
    end

    def self.route_type_to_gtfs(train_type)
        case train_type
        when "R"
            return 106
        when "R-E"
            return 106
        when "R-M"
            return 106
        when "IR"
            return 103
        when "IR-N"
            return 105
        when "IC"
            return 102
        else
            return 2
        end
    end

    def self.gtfs_data_routes_from_trips_data(trips_data)
        routes_map = {}
        route_id = 1

        trips_data.each do |trip_data|
            stop_ids = []
            stop_names = []
            trip_data['stops_data'].each do |stop_data|
                stop_id = stop_data['stop_id']
                stop_ids.push(stop_id)
                stop_names.push(stop_data['stop_name'])
            end

            route_key = stop_ids.join('_')
            if routes_map[route_key].nil?
                first_stop = trip_data['stops_data'].first
                last_stop = trip_data['stops_data'].last

                route_data = {
                    'route_id' => route_id,
                    'agency_id' => trip_data['agency_id'],
                    'route_long_name' => "#{first_stop['stop_name']} - #{last_stop['stop_name']}",
                    # https://developers.google.com/transit/gtfs/reference#routestxt
                    'route_type' => route_type_to_gtfs(trip_data['train_type_name']),
                }

                routes_map[route_key] = route_data
                route_id += 1
            end

            trip_data['route_id'] = routes_map[route_key]['route_id']
        end
        
        return routes_map.values
    end

    def self.gtfs_data_stops_from_trips_data(trips_data)
        stops_map = {}

        geojson_stops_map = {}
        geojson_stops_path = "#{APP_PATH}/cfr.webgis.ro/stops.geojson"
        geojson_stops = JSON.parse(File.open(geojson_stops_path, "r").read)
        geojson_stops['features'].each do |f|
            stop_id = f['properties']['station_id']
            geojson_stops_map[stop_id] = f
        end

        trips_data.each do |trip_data|
            trip_data['stops_data'].each do |stop_data|
                stop_id = stop_data['stop_id']
                if stops_map[stop_id].nil?
                    # GeoJSON specs: longitude, latitude
                    stop_coordinates = [0.0, 0.0]
                    geojson_stop_feature = geojson_stops_map[stop_id]
                    if geojson_stop_feature
                        stop_coordinates = geojson_stop_feature['geometry']['coordinates']
                    else
                        print "ERROR, no coordinates found for #{stop_data['stop_name']}(#{stop_id}) - check them with https://cfr.webgis.ro ?\n"
                    end

                    stop_row = {
                        'stop_id' => stop_id,
                        'stop_name' => stop_data['stop_name'],
                        'stop_lat' => stop_coordinates[1],
                        'stop_lon' => stop_coordinates[0],
                    }

                    stops_map[stop_id] = stop_row
                end
            end
        end

        stop_rows = stops_map.values.sort_by{ |el| el['stop_id'].to_i }

        return stop_rows
    end

    def self.gtfs_data_stop_times_from_trips_data(trips_data)
        stop_times_rows = []
        
        trips_data.each do |trip_data|
            trip_data['stops_data'].each_with_index do |stop_data, k|
                stop_data['stop_sequence'] = k + 1
                stop_data['trip_id'] = trip_data['trip_id']

                stop_times_rows.push(stop_data)
            end
        end

        return stop_times_rows
    end


    def self.write_gtfs_data(gtfs_data)
        print "Saving to GTFS...\n"

        settings = YAML.load_file("#{APP_PATH}/settings.yml")
        settings['gtfs_files'].keys.each do |file_name|
            rows = gtfs_data[file_name]
            if rows.nil?
                print "-- #{file_name.ljust(20, ' ')}:    0 rows - NO DATA\n"
                next
            end

            print "-- #{file_name.ljust(20, ' ')}: #{rows.size.to_s.rjust(5, ' ')} rows\n"

            field_names = settings['gtfs_files'][file_name]

            csv_write_path = "#{APP_PATH}/gtfs-out/#{file_name}.txt"
            CSV.open(csv_write_path, 'wb') do |csv_write|
                csv_write << field_names

                rows.each do |row|
                    csv_row_values = []
                    field_names.each do |field_name|
                        csv_row_values.push(row[field_name])
                    end

                    csv_write << csv_row_values
                end
            end
        end

        print "Check #{APP_PATH}/gtfs-out\n"
    end

end
