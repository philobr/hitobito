#  Copyright (c) 2017-2024, Jungwacht Blauring Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

require "spec_helper"

describe Export::EventParticipationsExportJob do
  subject { Export::EventParticipationsExportJob.new(format, user.id, event.id, groups(:top_group).id, params.merge(filename: filename)) }

  let(:participation) { event_participations(:top) }
  let(:user) { participation.person }
  let(:other_user) { Fabricate(:person, first_name: "Other", last_name: "Member", household_key: 1) }
  let(:event) { participation.event }
  let(:filename) { AsyncDownloadFile.create_name("event_participation_export", user.id) }

  let(:params) { {filter: "all"} }

  let(:file) do
    AsyncDownloadFile
      .from_filename(filename, format)
  end

  before do
    SeedFu.quiet = true
    SeedFu.seed [Rails.root.join("db", "seeds")]

    other_participation = Event::Participation.create(event: event, active: true, person: other_user)
    Event::Role::Participant.create(participation: other_participation)
  end

  context "creates a CSV-Export" do
    let(:format) { :csv }

    it "and saves it" do
      subject.perform

      lines = file.read.lines

      expect(lines.size).to eq(3)
      expect(lines[0]).to match(/Vorname;Nachname;Übername;Firmenname;.*/)
      expect(lines[0].split(";").count).to match(15)
    end
  end

  context "creates a full CSV-Export" do
    let(:format) { :csv }
    let(:params) { {details: true} }

    it "and saves it" do
      subject.perform

      lines = file.read.lines
      expect(lines.size).to eq(3)
      expect(lines[0]).to match(/Vorname;Nachname;Übername;Firmenname;.*/)
      expect(lines[0]).to match(/;Bemerkungen.*/)
      expect(lines[0].split(";").count).to match(25)
    end

    it "shows the correct timestamps on the participation instances" do
      created_at = 2.days.ago.change(usec: 0)
      updated_at = 1.day.ago.change(usec: 0)
      Event::Participation.update_all(created_at:, updated_at:)

      subject.perform

      lines = file.read.lines

      created_at_index = 24
      expect(lines[0].split(";")[created_at_index].strip).to eq("Anmeldedatum")
      csv_created_ats = lines[1..2].map { _1.split(";")[created_at_index].strip }
      expect(csv_created_ats).to all(eq(created_at.strftime("%d.%m.%Y")))
    end
  end

  context "creates a table displays export" do
    let(:format) { :csv }
    let(:params) { {selection: true} }

    it "and saves it" do
      TableDisplay.create!(person: user, table_model_class: "Event::Participation", selected: ["person.layer_group_label"])

      subject.perform

      lines = file.read.lines
      expect(lines.size).to eq(3)
      expect(lines[0]).to match(/Vorname;Nachname;Übername;Firmenname;.*/)
      expect(lines[0]).to match(/Hauptebene.*/)
      expect(lines[0].split(";").count).to match(16)
      expect(lines[1]).to eq "Bottom;Member;;;nein;bottom_member@example.com;;Greatstreet;345;;3456;Greattown;Schweiz;Bottom One;Member Bottom One;Bottom One\n"
    end
  end

  context "creates a household export" do
    let(:format) { :csv }
    let(:params) { {household: true} }

    it "and saves it" do
      user.update(household_key: 1)
      other_user.update(household_key: 1)

      subject.perform

      lines = file.read.lines
      expect(lines.size).to eq(2)
      expect(lines[0]).to match(/Name;Adresse;PLZ;.*/)
      expect(lines[1]).to match(/Bottom und Other Member.*/).or match(/Other und Bottom Member.*/)
    end
  end

  context "creates an Excel-Export" do
    let(:format) { :xlsx }

    it "and saves it" do
      subject.perform

      expect(file.generated_file).to be_attached
    end
  end
end
