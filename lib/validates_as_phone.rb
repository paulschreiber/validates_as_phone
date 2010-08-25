module ActiveRecord
  module Validations
    module ClassMethods
      def regex_for_country(country_code)
        if country_code.blank?
          nil
        elsif ["AU"].include?(country_code)
          /(^(1300|1800|1900|1902)\d{6}$)|(^([0]?[1|2|3|7|8])?[1-9][0-9]{7}$)|(^13\d{4}$)|(^[0]?4\d{8}$)/
        elsif ["US", "CA"].include?(country_code)
          /[2-9]\d{2}[2-9]\d{2}\d{4}/
        else
          nil
        end
      end
      

      def validates_as_phone(*args)        
        configuration = { :message => ActiveRecord::Errors.default_error_messages[:invalid],
                          :on => :save, :with => nil,
                          :country => :phone_country, :area_key => :phone_area_key
                        }
        configuration.update(args.pop) if args.last.is_a?(Hash)

        current_regex = regex_for_country(configuration[:country])
        return false unless current_regex

        validates_each(args, configuration) do |record, attr_name, value|
          new_value = value.to_s.gsub(/[^0-9]/, '')
          new_value ||= ''

          unless (configuration[:allow_blank] && new_value.blank?) || new_value =~ current_regex
            record.errors.add(attr_name, configuration[:message])
          else
            record.send(attr_name.to_s + '=',
              format_as_phone(new_value, record.send(configuration[:country]), record.send(configuration[:area_key]))
            ) if configuration[:set]
          end
        end
      end

      def format_as_phone(arg, country_code = nil, area_key = nil)
        return nil if (arg.blank? or country_code.blank? or !REGEX_LIST.has_key?(country_code))

        number = arg.gsub(/[^0-9]/, '')

        if country_code == "AU"
          if number =~ /^(1300|1800|1900|1902)\d{6}$/
            number.insert(4, ' ').insert(8, ' ')
          elsif number =~ /^([0]?[1|2|3|7|8])?[1-9][0-9]{7}$/
            if number =~ /^[1-9][0-9]{7}$/
              number = number.insert(0, area_code_for_key(area_key))
            end
            number = number.insert(0, '0') if number =~ /^[1|2|3|7|8][1-9][0-9]{7}$/

            number.insert(0, '(').insert(3, ') ').insert(9, ' ')
          elsif number =~ /^13\d{4}$/
            number.insert(2, ' ').insert(5, ' ')
          elsif number =~ /^[0]?4\d{8}$/
            number = number.insert(0, '0') if number =~ /^4\d{8}$/

            number.insert(4, ' ').insert(8, ' ')
          else
            number
          end
        elsif ["CA", "US"].include?(country_code)
          digit_count = number.length
          if digit_count < 10 or digit_count > 11
            return number
          end

          # if it's 11 digits and doesn't start with a 1
          if digit_count == 11 and number[0..0] != "1"
            return number
          end

          # if it's 11 digits and starts with a 1, chop off the one
          if digit_count == 11
            number = number[1..10]
          end

          area_code = number[0..2]
          exchange = number[3..5]
          suffix = number[6..9]

          number = "(%s) %s-%s" % [area_code, exchange, suffix]
        end
      end

      def area_code_for_key(key)
        case key
          when 'NSW': '02'
          when 'ACT': '02'
          when 'VIC': '03'
          when 'TAS': '03'
          when 'QLD': '07'
          when 'SA' : '08'
          when 'NT' : '08'
          when 'WA' : '08'
        else
          '02'
        end
      end
    end    
  end
end
