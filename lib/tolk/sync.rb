module Tolk
  module Sync
    def self.included(base)
      base.send :extend, ClassMethods
    end

    module ClassMethods
      def sync!
        raise "Primary locale is not set. Please set Locale.primary_locale_name in your application's config file" unless self.primary_locale_name

        translations = read_primary_locale_file
        sync_phrases(translations)
      end

      def read_primary_locale_file
        primary_file = "#{self.locales_config_path}/#{self.primary_locale_name}.yml"
        raise "Primary locale file #{primary_file} does not exists" unless File.exists?(primary_file)

        flat_hash(YAML::load(IO.read(primary_file))[self.primary_locale_name])
      end

      private

      def sync_phrases(translations)
        primary_locale = self.primary_locale
        secondary_locales = self.secondary_locales

        # Handle deleted phrases
        translations.present? ? Phrase.destroy_all(["phrases.key NOT IN (?)", translations.keys]) : Phrase.destroy_all

        phrases = Phrase.all

        translations.each do |key, value|
          # Create phrase and primary translation if missing
          existing_phrase = phrases.detect {|p| p.key == key} || Phrase.create!(:key => key)
          translation = existing_phrase.translations.primary || primary_locale.translations.build(:phrase_id => existing_phrase.id)

          # Update primary translation if it's been changed
          if value.present? && translation.text != value
            translation.text = value 
            translation.save!
          end

          # Make sure the translation record exists for all the locales
          # secondary_locales.each do |locale|
          #   existing_translation = existing_phrase.translations.detect {|t| t.locale_id == locale.id }
          #   locale.translations.create!(:phrase_id => existing_phrase.id) unless existing_translation
          # end
        end
      end

      def flat_hash(data, prefix = '', result = {})
        data.each do |key, value|
          current_prefix = prefix.present? ? "#{prefix}.#{key}" : key

          if value.is_a?(Hash)
            flat_hash(value, current_prefix, result)
          else
            result[current_prefix] = value
          end
        end

        result
      end

    end

  end
end
