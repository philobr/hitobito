#  Copyright (c) 2012-2020, CVP Schweiz. This file is part of
#  hitobito_cvp and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_cvp.

class Address::ImportJob < RecurringJob
  run_every 6.months

  def perform_internal
    return unless configured?

    Address::Importer.new.run
  end

  def configured?
    Settings.addresses.url.present? && Settings.addresses.token.present?
  end
end
