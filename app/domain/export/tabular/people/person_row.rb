#  Copyright (c) 2012-2024, Jungwacht Blauring Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

module Export::Tabular::People
  class PersonRow < Export::Tabular::Row
    self.dynamic_attributes = {/^phone_number_/ => :phone_number_attribute,
                                /^social_account_/ => :social_account_attribute,
                                /^additional_email_/ => :additional_email_attribute,
                                /^additional_address_/ => :additional_address_attribute,
                                /^qualification_kind_/ => :qualification_kind}

    def country
      entry.country_label
    end

    def gender
      entry.gender_label
    end

    def roles
      if entry.try(:role_with_layer).present?
        entry.roles.zip(entry.role_with_layer.split(", ")).map { |arr| arr.join(" ") }.join(", ")
      else
        entry.roles.map { |role| "#{role} #{role.group.with_layer.join(" / ")}" }.join(", ")
      end
    end

    def tags
      entry.tag_list.to_s
    end

    def layer_group
      entry.layer_group.to_s
    end

    def address
      entry.address
    end

    private

    def phone_number_attribute(attr)
      contact_account_attribute(entry.phone_numbers, attr)
    end

    def social_account_attribute(attr)
      contact_account_attribute(entry.social_accounts, attr)
    end

    def additional_email_attribute(attr)
      contact_account_attribute(entry.additional_emails, attr)
    end

    def additional_address_attribute(attr)
      contact_account_attribute(entry.additional_addresses, attr)
    end

    def qualification_kind(attr)
      qualification = find_qualification(attr)
      qualification.finish_at.try(:to_s) || I18n.t("global.yes") if qualification
    end

    def find_qualification(label)
      entry.decorate.latest_qualifications_uniq_by_kind.find do |q|
        qualification_active?(q) &&
          ContactAccounts.key(q.qualification_kind.class, q.qualification_kind.label) == label
      end
    end

    def qualification_active?(q)
      (q.start_at.blank? || q.start_at <= Time.zone.today) &&
        (q.finish_at.blank? || q.finish_at >= Time.zone.today)
    end

    def contact_account_attribute(accounts, attr)
      account = accounts.find do |e|
        ContactAccounts.key(e.class, e.translated_label) == attr
      end
      account.value if account
    end
  end
end
