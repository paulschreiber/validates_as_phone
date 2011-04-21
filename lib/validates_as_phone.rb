module ActiveRecord
  module Validations
    module ClassMethods
      AU_AREA_CODES = {:NSW => '02', :ACT => '02', :VIC => '03', :TAS => '03', :QLD => '07', :SA => '08', :NT => '08', :WA => '08'}

      def regex_for_country(country_code)
        if [:AU].include?(country_code)
          /(^(1300|1800|1900|1902)\d{6}$)|(^([0]?[1|2|3|7|8])?[1-9][0-9]{7}$)|(^13\d{4}$)|(^[0]?4\d{8}$)/
        elsif [:US, :CA].include?(country_code)
          /^1?[2-9]\d{2}[2-9]\d{2}\d{4}/
        end
      end

      def validates_as_phone(*args)
        configuration = { :with => nil, :area_key => :phone_area_key }
        configuration.update(args.pop) if args.last.is_a?(Hash)

        validates_each(args, configuration) do |record, attr_name, value|
          country = if configuration[:country].is_a?(String)
            configuration[:country]
          elsif configuration[:country].is_a?(Symbol) and record.respond_to?(configuration[:country])
            record.send configuration[:country]
          elsif record.respond_to?(:country)
            record.send :country
          else
            false
          end

          next unless country
          current_regex = regex_for_country country
          next unless current_regex

          new_value = value.to_s.gsub(/[^0-9]/, '') || ''

          message = I18n.t("activerecord.errors.models.#{name.underscore}.attributes.#{attr_name}.invalid",
                                        :default => [:"activerecord.errors.models.#{name.underscore}.invalid",
                                                    configuration[:message],
                                                    :'activerecord.errors.messages.invalid'])

          if (configuration[:allow_blank] && new_value.blank?) || new_value =~ current_regex
            if configuration[:set]
              formatted_phone = format_as_phone value, country, configuration[:area_key]
              if formatted_phone.nil?
                record.errors.add attr_name, message
              else
                record.send attr_name.to_s + '=', formatted_phone
              end
            end # configuration
          else
            record.errors.add attr_name, message
          end # unless
        end # validates_each
      end

      def format_as_phone(arg, country_code = nil, area_key = nil)
        country_code = country_code.to_sym
        return if (arg.blank? or country_code.blank? or !regex_for_country(country_code))

        number = arg.gsub /[^0-9]/, ''

        if country_code == :AU
          case number
          when /^(1300|1800|1900|1902)\d{6}$/
            number.insert(4, ' ').insert(8, ' ')
          when /^([0]?[1|2|3|7|8])?[1-9][0-9]{7}$/
            number.insert(0, area_code_for_key(area_key)) if number =~ /^[1-9][0-9]{7}$/
            number.insert(0, '0') if number =~ /^[1|2|3|7|8][1-9][0-9]{7}$/

            number.insert(0, '(').insert(3, ') ').insert(9, ' ')
          when /^13\d{4}$/
            number.insert(2, ' ').insert(5, ' ')
          when /^[0]?4\d{8}$/
            number.insert(0, '0') if number =~ /^4\d{8}$/
            number.insert(4, ' ').insert(8, ' ')
          else
            number
          end
        elsif [:CA, :US].include?(country_code)
          # if it's too short
          return number if number.length < 10

          number = number[1..10] if number[0..0] == "1" # strip off any leading ones

          area_code, exchange, sln = number[0..2], number[3..5], number[6..9]

          extension = if number.length == 10
            nil
          else
            # save everything after the SLN as extension
            sln_index = arg.index sln
            # if something went wrong, return nil so we can error out
            # i.e. 519 444 000 ext 123 would cause sln to be 0001, which is not found
            # in the original string
            return if sln_index.nil?
            " %s" % arg[(sln_index+4)..-1].strip
          end

          "(%s) %s-%s%s" % [area_code, exchange, sln, extension]
        end
      end

      def area_code_for_key(key)
        AU_AREA_CODES[key.to_sym] || '02'
      end
    end
  end
end
