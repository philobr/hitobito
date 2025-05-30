#  Copyright (c) 2014, Pfadibewegung Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.
# == Schema Information
#
# Table name: additional_emails
#
#  id               :integer          not null, primary key
#  contactable_type :string           not null
#  email            :string           not null
#  invoices         :boolean          default(FALSE)
#  label            :string
#  mailings         :boolean          default(TRUE), not null
#  public           :boolean          default(TRUE), not null
#  contactable_id   :integer          not null
#
# Indexes
#
#  idx_on_invoices_contactable_id_contactable_type_9f308c8a16      (invoices,contactable_id,contactable_type) WHERE (((contactable_type)::text = 'AdditionalEmail'::text) AND (invoices = true))
#  index_additional_emails_on_contactable_id_and_contactable_type  (contactable_id,contactable_type)
#

require "spec_helper"

describe AdditionalEmail do
  after do
    I18n.locale = I18n.default_locale
  end

  context "label validation" do
    it "should not contain a dot at the end of a label" do
      a1 = Fabricate(:additional_email, label: "Foo")
      expect(a1).to be_valid

      a1.label = "Foo."
      expect(a1).not_to be_valid
    end
  end

  context "invoices validation" do
    it "validates uniqueness of invoices for contactable" do
      a1 = Fabricate(:additional_email, label: "Foo", invoices: true, contactable: people(:top_leader))
      expect(a1).to be_valid

      a2 = Fabricate.build(:additional_email, label: "Bar", invoices: true, contactable: people(:top_leader))
      expect(a2).not_to be_valid
      expect(a2).to have(1).error_on(:invoices)

      a3 = Fabricate.build(:additional_email, label: "Buz", invoices: true, contactable: people(:bottom_member))
      expect(a3).to be_valid

      a4 = Fabricate(:additional_email, label: "Buz", invoices: false, contactable: people(:top_leader))
      expect(a4).to be_valid

      a5 = Fabricate(:additional_email, label: "Buzz", invoices: false, contactable: people(:top_leader))
      expect(a5).to be_valid
    end
  end

  describe "e-mail validation" do
    let(:add_email) { Fabricate(:additional_email, label: "Foo") }

    before { allow(Truemail).to receive(:valid?).and_call_original }

    it "does not allow invalid e-mail address" do
      add_email.email = "blabliblu-ke-email"

      expect(add_email).not_to be_valid
      expect(add_email.errors.messages[:email].first).to eq("ist nicht gültig")
    end

    it "does not allow e-mail address with non-existing domain" do
      add_email.email = "dude@gitsäuäniä.it"

      expect(add_email).not_to be_valid
      expect(add_email.errors.messages[:email].first).to eq("ist nicht gültig")
    end

    it "does not allow e-mail address with domain without mx record" do
      add_email.email = "dude@bluewin.com"

      expect(add_email).not_to be_valid
      expect(add_email.errors.messages[:email].first).to eq("ist nicht gültig")
    end

    it "does allow valid e-mail address" do
      add_email.email = "dude@puzzle.ch"

      expect(add_email).to be_valid
    end
  end

  describe "normalization" do
    let(:add_email) { Fabricate(:additional_email, label: "Foo") }

    it "downcases email" do
      add_email.email = "TesTer@gMaiL.com"
      expect(add_email.email).to eq "tester@gmail.com"
    end
  end

  context "#translated_label" do
    it "should return untranslated label as-is" do
      I18n.locale = :fr

      a1 = Fabricate(:additional_email, label: "Foo")
      expect(a1.label).to eq "Foo"
      expect(a1.translated_label).to eq "Foo"
    end

    it "should return translated label" do
      I18n.locale = :fr

      a2 = Fabricate(:additional_email, label: "Privat")
      expect(a2.label).to eq "Privat"
      expect(a2.translated_label).to eq "Privé"
    end
  end

  context ".normalize_label" do
    it "reuses existing label" do
      Fabricate(:additional_email, label: "Foo")
      a2 = Fabricate(:additional_email, label: "fOO")
      expect(a2.label).to eq("Foo")
    end

    it "should preserve untranslated label as-is" do
      I18n.locale = :fr

      a1 = Fabricate(:additional_email, label: "Foo")
      expect(a1.label).to eq "Foo"
    end

    it "should map label back to default language" do
      I18n.locale = :fr

      a2 = Fabricate(:additional_email, label: "privé")
      expect(a2.label).to eq "Privat"
    end
  end

  context "#available_labels" do
    subject { AdditionalEmail.available_labels }

    before do
      @settings_langs = Settings.application.languages
      Settings.application.languages = {de: "Deutsch", fr: "Français"}
    end

    after do
      Settings.application.languages = @settings_langs
    end

    it { is_expected.to include(Settings.additional_email.predefined_labels.first) }

    it "excludes labels from database" do
      Fabricate(:additional_email, label: "Foo")
      is_expected.not_to include("Foo")
    end

    it "translates labels where available" do
      I18n.locale = :de
      expect(AdditionalEmail.available_labels).not_to include("Privé")

      I18n.locale = :fr
      expect(AdditionalEmail.available_labels).to include("Privé")
    end
  end

  context "#used_labels" do
    subject { AdditionalEmail.used_labels }

    it "is sweeped for all languages if new label is added" do
      Rails.cache.clear

      expect(I18n.locale).to eq :de
      labels_de = AdditionalEmail.used_labels

      I18n.locale = :fr
      labels_fr = AdditionalEmail.used_labels

      expect(labels_de).not_to eq labels_fr

      Fabricate(:additional_email, label: "A new label")
      expect(AdditionalEmail.used_labels).to eq labels_fr + ["A new label"]

      I18n.locale = :de
      expect(AdditionalEmail.used_labels).to eq labels_de + ["A new label"]
    end
  end

  context "paper trails", versioning: true do
    let(:person) { people(:top_leader) }

    it "sets main on create" do
      expect do
        person.additional_emails.create!(label: "Foo", email: "bar@bar.com")
      end.to change { PaperTrail::Version.count }.by(1)

      version = PaperTrail::Version.order(:created_at, :id).last
      expect(version.event).to eq("create")
      expect(version.main).to eq(person)
    end

    it "sets main on update" do
      account = person.additional_emails.create(label: "Foo", email: "bar@bar.com")
      expect do
        account.update!(email: "bur@bur.com")
      end.to change { PaperTrail::Version.count }.by(1)

      version = PaperTrail::Version.order(:created_at, :id).last
      expect(version.event).to eq("update")
      expect(version.main).to eq(person)
    end

    it "sets main on destroy" do
      account = person.additional_emails.create(label: "Foo", email: "bar@bar.com")
      expect do
        account.destroy!
      end.to change { PaperTrail::Version.count }.by(1)

      version = PaperTrail::Version.order(:created_at, :id).last
      expect(version.event).to eq("destroy")
      expect(version.main).to eq(person)
    end
  end
end
