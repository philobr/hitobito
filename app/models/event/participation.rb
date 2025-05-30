# frozen_string_literal: true

#  Copyright (c) 2012-2021, Jungwacht Blauring Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

# == Schema Information
#
# Table name: event_participations
#
#  id                     :integer          not null, primary key
#  active                 :boolean          default(FALSE), not null
#  additional_information :text
#  qualified              :boolean
#  created_at             :datetime
#  updated_at             :datetime
#  application_id         :integer
#  event_id               :integer          not null
#  person_id              :integer          not null
#
# Indexes
#
#  index_event_participations_on_application_id          (application_id)
#  index_event_participations_on_event_id                (event_id)
#  index_event_participations_on_event_id_and_person_id  (event_id,person_id) UNIQUE
#  index_event_participations_on_person_id               (person_id)
#

class Event::Participation < ActiveRecord::Base
  # These mails can be manually sent to participants in the participation show page via a dropdown
  MANUALLY_SENDABLE_PARTICIPANT_MAILS = [
    Event::ParticipationMailer::CONTENT_CONFIRMATION
  ]

  self.demodulized_route_keys = true

  attr_accessor :enforce_required_answers

  ### ASSOCIATIONS

  belongs_to :event, -> { includes(:translations) }, inverse_of: :participations
  belongs_to :person

  belongs_to :application, inverse_of: :participation, dependent: :destroy, validate: true

  has_many :roles, inverse_of: :participation, dependent: :destroy

  has_many :answers, dependent: :destroy, validate: true

  accepts_nested_attributes_for :answers, :application

  ### VALIDATIONS

  # price_category is used as enum in hitobito_sac_cas. validates_by_schema cannot be overridden
  # inside a wagon because of the loading order, so it must be excluded in the core instead
  validates_by_schema except: [:price_category]
  validates :person_id,
    uniqueness: {scope: :event_id}
  validates :additional_information,
    length: {allow_nil: true, maximum: (2**16) - 1}

  ### CALLBACKS

  before_validation :init, on: :create
  before_validation :set_self_in_nested
  before_create :reset_person_minimized_at

  # There may be old participations without roles, so they must
  # update the count directly.
  after_destroy :update_participant_count

  ### CLASS METHODS

  class << self
    # Order people by the order participation types are listed in their event types.
    def order_by_role(event_type)
      joins(:roles)
        .select("event_participations.*", :order_weight)
        .joins("INNER JOIN event_role_type_orders ON event_roles.type = event_role_type_orders.name")
        .order("event_role_type_orders.order_weight ASC")
    end

    def active
      where(active: true)
    end

    def pending
      where(active: false)
    end

    def upcoming
      joins(:event).merge(Event.upcoming(::Time.zone.today)).distinct
    end
  end

  ### INSTANCE METHODS

  def init_answers
    answers.tap do |list|
      event.questions.list.each do |question|
        next if question.hidden?
        next if list.find { |answer| answer.question_id == question.id }

        list << question.answers.new(question: question) # without this, only the id is set
      end
    end
  end

  def init_application
    return unless applying_participant?

    (application || build_application).tap do |appl|
      appl.priority_1 = event
      if directly_to_waiting_list?(event)
        appl.waiting_list = true
        appl.waiting_list_comment = I18n.t("event/applications.directly_to_waiting_list")
      end
    end
  end

  def applying_participant?
    first_role_class = roles.first&.class
    event.supports_applications && (application_id || first_role_class&.participant?)
  end

  def waiting_list?
    application&.waiting_list? || false
  end

  def pending?
    !active
  end

  def to_s
    person.to_s
  end

  private

  def set_self_in_nested
    # don't try to set self in frozen nested attributes (-> marked for destroy)
    answers.each { |e| e.participation = self unless e.frozen? }
  end

  def reset_person_minimized_at
    person.minimized_at = nil
  end

  def init
    init_answers
    init_application
    true
  end

  def update_participant_count
    event.refresh_participant_counts!
  end

  def directly_to_waiting_list?(event)
    !event.places_available? && event.waiting_list_available?
  end
end
