# frozen_string_literal: true

# == Schema Information
#
# Table name: payment_provider_configs
#
#  id                 :bigint           not null, primary key
#  encrypted_keys     :text
#  encrypted_password :string
#  partner_identifier :string
#  payment_provider   :string
#  status             :integer          default("draft"), not null
#  synced_at          :datetime
#  user_identifier    :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  invoice_config_id  :bigint
#
# Indexes
#
#  index_payment_provider_configs_on_invoice_config_id  (invoice_config_id)
#

require "spec_helper"

describe PaymentProviderConfig do
  let(:postfinance_config) { payment_provider_configs(:postfinance) }
  let(:ubs_config) { payment_provider_configs(:ubs) }

  it "encrypts keys" do
    postfinance_config.keys = "bla,bli,blup"

    expect(postfinance_config.encrypted_keys[:encrypted_value]).to be_present
    expect(postfinance_config.encrypted_keys[:iv]).to be_present
    expect(postfinance_config.encrypted_keys[:encrypted_value]).to_not eq("bla,bli,blup")
    expect(postfinance_config.keys).to eq("bla,bli,blup")

    expect(postfinance_config.save).to be(true)
  end

  it "encrypts password" do
    postfinance_config.password = "passwördli13!"

    expect(postfinance_config.encrypted_password[:encrypted_value]).to be_present
    expect(postfinance_config.encrypted_password[:iv]).to be_present
    expect(postfinance_config.encrypted_password[:encrypted_value]).to_not eq("password")
    expect(postfinance_config.password).to eq("passwördli13!")

    expect(postfinance_config.save).to be(true)
  end

  it "sets status to draft as default" do
    payment_provider_config = described_class.new

    expect(payment_provider_config.status).to eq("draft")
  end

  context "after_delete" do
    it "deletes all associated ebics import jobs" do
      Payments::EbicsImportJob.new(postfinance_config.id).enqueue!(run_at: 10.seconds.from_now)
      Payments::EbicsImportJob.new(ubs_config.id).enqueue!(run_at: 10.seconds.from_now)

      expect do
        postfinance_config.destroy!
      end.to change { Delayed::Job.count }.by(-1)

      query = "handler LIKE '%Payments::EbicsImportJob%payment_provider_config_id: ?%'"
      expect(Delayed::Job.where(query, postfinance_config.id)).to be_empty
      expect(Delayed::Job.where(query, ubs_config.id)).to be_present
    end
  end
end
