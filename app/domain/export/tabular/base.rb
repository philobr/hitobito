#  Copyright (c) 2012-2017, insieme Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.
#

module Export::Tabular
  # Base class for csv/xlsx export
  class Base
    class_attribute :model_class, :row_class, :auto_filter, :batch_size
    self.row_class = Export::Tabular::Row
    self.auto_filter = true
    self.batch_size = 1000

    attr_reader :ability, :list

    class << self
      def export(format, *)
        generator(format).new(new(*)).call
      end

      def xlsx(*)
        export(:xlsx, *)
      end

      def csv(*)
        export(:csv, *)
      end

      private

      def generator(format)
        case format
        when :csv then Export::Csv::Generator
        when :xlsx then Export::Xlsx::Generator
        else raise ArgumentError, "Invalid format #{format}"
        end
      end
    end

    def initialize(list, ability = nil)
      @list = list
      @ability = ability
    end

    # The list of all attributes exported to the csv/xlsx.
    # override either this or #attribute_labels
    def attributes
      attribute_labels.keys
    end

    # A hash of all attributes mapped to their labels exported to the csv/xlsx.
    # overridde either this or #attributes
    def attribute_labels
      @attribute_labels ||= build_attribute_labels
    end

    # List of all labels.
    def labels
      attribute_labels.values
    end

    def header_rows
      @header_rows ||= []
    end

    def data_rows(format = nil)
      return enum_for(:data_rows) unless block_given?

      Iterator.new(list, batch_size).each do |entry|
        yield values(entry, format)
      end
    end

    private

    def build_attribute_labels
      attributes.each_with_object({}) do |attr, labels|
        labels[attr] = attribute_label(attr)
      end
    end

    def attribute_label(attr)
      label_method = "#{attr}_label"
      respond_to?(label_method) ? send(label_method) : human_attribute(attr)
    end

    def human_attribute(attr)
      model_class.human_attribute_name(attr)
    end

    def values(entry, format = nil)
      row = row_for(entry, format)
      attributes.collect { |attr| row.fetch(attr) }
    end

    def row_for(entry, format = nil)
      row = row_class.new(entry, format)
      # see comment in Export::Tabular::Row for explanation
      # why this is not included in `new()`
      row.ability = ability
      row
    end
  end
end
