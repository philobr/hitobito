#  Copyright (c) 2012-2020, Jungwacht Blauring Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

# == Schema Information
#
# Table name: sessions
#
#  id         :integer          not null, primary key
#  data       :text
#  created_at :datetime
#  updated_at :datetime
#  session_id :string           not null
#
# Indexes
#
#  index_sessions_on_session_id  (session_id)
#  index_sessions_on_updated_at  (updated_at)
#

class Session < ActiveRecord::SessionStore::Session
  before_save :set_person_id

  def self.outdated
    where(updated_at: ...1.month.ago)
  end

  private

  def set_person_id
    self.person_id ||= data.dig("warden.user.person.key", 0, 0) if data.is_a?(Hash)
  end
end
