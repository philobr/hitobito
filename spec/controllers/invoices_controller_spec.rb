#  Copyright (c) 2017-2024, Jungwacht Blauring Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

require "spec_helper"

describe InvoicesController do
  let(:group) { groups(:bottom_layer_one) }
  let(:person) { people(:bottom_member) }
  let(:invoice) { invoices(:invoice) }

  before { sign_in(person) }

  context "authorization" do
    it "may index when person has finance permission on layer group" do
      get :index, params: {group_id: group.id}
      expect(response).to be_successful
    end

    it "may edit when person has finance permission on layer group" do
      invoice = Invoice.create!(group: group, title: "test", recipient: person)
      get :edit, params: {group_id: group.id, id: invoice.id}
      expect(response).to be_successful
    end

    it "may not index when person has no finance permission on layer group" do
      expect do
        get :index, params: {group_id: groups(:top_layer).id}
      end.to raise_error(CanCan::AccessDenied)
    end

    it "may not edit when person has no finance permission on layer group" do
      invoice = Invoice.create!(group: groups(:top_layer), title: "test", recipient: person)
      expect do
        get :edit, params: {group_id: groups(:top_layer).id, id: invoice.id}
      end.to raise_error(CanCan::AccessDenied)
    end
  end

  context "new" do
    it "GET#new supports creating invoice for without recipient_id" do
      get :new, params: {group_id: group.id}
      expect(response).to be_successful
      expect(assigns(:invoice).recipient_id).to be_nil
      expect(assigns(:invoice).recipient_address).to be_nil
    end

    it "GET#new creating invoice for with recipient_id" do
      get :new, params: {group_id: group.id, invoice: {recipient_id: person.id}}
      expect(response).to be_successful
      expect(assigns(:invoice).recipient).to be_present
      expect(assigns(:invoice).recipient_address).to be_present
    end
  end

  context "index" do
    it "GET#index finds invoices by title" do
      update_issued_at_to_current_year
      get :index, params: {group_id: group.id, q: "Invoice"}
      expect(assigns(:invoices)).to have(1).item
    end

    it "GET#index finds invoices by sequence_number" do
      get :index, params: {group_id: group.id, q: invoices(:invoice).sequence_number}
      expect(assigns(:invoices)).to have(1).item
    end

    it "GET#index finds invoices by recipient.last_name" do
      update_issued_at_to_current_year
      get :index, params: {group_id: group.id, q: people(:top_leader).last_name}
      expect(assigns(:invoices)).to have(2).item
    end

    it "GET#index finds invoices by recipient.first_name" do
      update_issued_at_to_current_year
      get :index, params: {group_id: group.id, q: people(:top_leader).first_name}
      expect(assigns(:invoices)).to have(2).item
    end

    it "GET#index finds invoices by recipient.email" do
      update_issued_at_to_current_year
      get :index, params: {group_id: group.id, q: people(:top_leader).email}
      expect(assigns(:invoices)).to have(2).item
    end

    it "GET#index finds invoices by recipient.company_name" do
      update_issued_at_to_current_year
      people(:top_leader).update!(company_name: "Hitobito Fanclub")
      get :index, params: {group_id: group.id, q: "hitobito"}
      expect(assigns(:invoices)).to have(2).item
    end

    it "GET#index finds nothing by owner.company_name" do
      update_issued_at_to_current_year
      creator = people(:bottom_member)
      creator.update!(company_name: "Greedy Ltd")
      Invoice.update_all(creator_id: creator.id)
      get :index, params: {group_id: group.id, q: creator.company_name}
      expect(assigns(:invoices)).to be_empty
    end

    it "GET#index finds nothing for dummy" do
      get :index, params: {group_id: group.id, q: "dummy"}
      expect(assigns(:invoices)).to be_empty
    end

    it "filters invoices by state" do
      get :index, params: {group_id: group.id, state: :draft}
      expect(assigns(:invoices)).to have(1).item
    end

    it "filters invoices by daterange" do
      invoice.update(issued_at: Time.zone.today)
      get :index, params: {group_id: group.id,
                           from: 1.year.ago.beginning_of_year,
                           to: 1.year.ago.end_of_year}
      expect(assigns(:invoices)).not_to include invoice
    end

    it "filters invoices by year with default set to current year" do
      invoice.update(issued_at: Time.zone.today)
      travel_to(1.year.ago) do
        get :index, params: {group_id: group.id}
      end
      expect(assigns(:invoices)).not_to include invoice
    end

    it "filters invoices by due_since" do
      invoice.update(due_at: 2.weeks.ago)
      get :index, params: {group_id: group.id, due_since: :one_week}
      expect(assigns(:invoices)).to have(1).item
    end

    it "ignores page param when passing in ids" do
      update_issued_at_to_current_year
      get :index, params: {group_id: group.id, ids: Invoice.pluck(:id).join(","), page: 2}
      expect(assigns(:invoices)).to have(2).items
    end

    it "exports pdf in background" do
      update_issued_at_to_current_year
      expect do
        get :index, params: {group_id: group.id}, format: :pdf
      end.to change { Delayed::Job.count }.by(1)
    end

    context "invoice list" do
      let(:sent) { invoices(:sent) }
      let(:letter) { messages(:with_invoice) }
      let(:invoice_list) { messages(:with_invoice).create_invoice_list(title: "test", group_id: group.id) }
      let(:top_leader) { people(:top_leader) }

      before do
        update_issued_at_to_current_year
        sent.update(invoice_list: invoice_list)
      end

      it "does not include invoice when viewing group invoices" do
        get :index, params: {group_id: group.id}
        expect(assigns(:invoices)).not_to include sent
      end

      it "does include invoice when viewing invoice list invoices" do
        get :index, params: {group_id: group.id, invoice_list_id: invoice_list.id}
        expect(assigns(:invoices)).to include sent
      end

      it "does render pdf using invoice renderer" do
        expect do
          get :index, params: {group_id: group.id, invoice_list_id: invoice_list.id}, format: :pdf
        end.to change { Delayed::Job.count }.by(1)
      end

      it "does render pdf Letter renderer renderer" do
        top_leader.update(
          street: "Greatstreet",
          housenumber: "345",
          zip_code: 3456,
          town: "Greattown",
          country: "CH"
        )

        invoice_list.update(message: letter)

        expect(Export::MessageJob).to receive(:new)
          .with(:pdf, person.id, letter.id, Hash)
          .and_call_original
        expect do
          get :index, params: {group_id: group.id, invoice_list_id: invoice_list.id}, format: :pdf
        end.to change { Delayed::Job.count }.by(1)
      end
    end

    it "exports labels pdf" do
      get :index, params: {group_id: group.id, label_format_id: label_formats(:standard).id}, format: :pdf
      expect(response.media_type).to eq("application/pdf")
    end

    it "exports pdf" do
      update_issued_at_to_current_year
      get :index, params: {group_id: group.id}, format: :csv
      expect(response.header["Content-Disposition"]).to match(/rechnungen.csv/)
      expect(response.media_type).to eq("text/csv")
    end

    it "renders json" do
      update_issued_at_to_current_year
      get :index, params: {group_id: group.id}, format: :json
      json = JSON.parse(response.body).deep_symbolize_keys
      expect(json[:current_page]).to eq 1
      expect(json[:total_pages]).to eq 1
      expect(json[:next_page_link]).to be_nil
      expect(json[:prev_page_link]).to be_nil
      expect(json[:invoices]).to have(2).items

      expect(json[:invoices].first[:links][:invoice_items]).to have(2).items
      expect(json[:invoices].last[:links][:invoice_items]).to have(1).items

      expect(json[:linked][:groups]).to have(1).item
      expect(json[:linked][:groups].first[:id].to_i).to eq groups(:bottom_layer_one).id

      expect(json[:linked][:invoice_items]).to have(3).items

      expect(json[:links][:"invoices.creator"][:href]).to eq "http://test.host/people/{invoices.creator}.json"
      expect(json[:links][:"invoices.recipient"][:href]).to eq "http://test.host/people/{invoices.recipient}.json"
    end

    context "rendering view" do
      render_views
      let(:dom) { Capybara::Node::Simple.new(response.body) }

      it "renders invoice with title" do
        invoice.update(title: "Testrechnung")
        get :index, params: {group_id: group.id}
        expect(dom).to have_link "Testrechnung", href: group_invoice_path(group_id: group.id, id: invoice.id)
      end
    end
  end

  context "show" do
    it "GET#show assigns payment if invoice has been sent" do
      invoice.update(state: :sent)
      get :show, params: {group_id: group.id, id: invoice.id}
      expect(assigns(:payment)).to be_present
      expect(assigns(:payment_valid)).to eq true
      expect(assigns(:payment).amount.to_f).to eq 5.35
    end

    it "GET#show assigns payment with amount_open" do
      invoice.update(state: :sent)
      invoice.payments.create!(amount: 0.5)
      get :show, params: {group_id: group.id, id: invoice.id}
      expect(assigns(:payment)).to be_present
      expect(assigns(:payment_valid)).to eq true
      expect(assigns(:payment).amount.to_f).to eq 4.85
    end

    it "GET#show assigns payment with flash parameters" do
      invoice.update(state: :sent)
      allow(subject).to receive(:flash).and_return(payment: {})
      get :show, params: {group_id: group.id, id: invoice.id}
      expect(assigns(:payment)).to be_present
      expect(assigns(:payment_valid)).to eq false
    end

    it "exports pdf" do
      expect do
        get :show, params: {group_id: group.id, id: invoice.id}, format: :pdf
      end.to change { Delayed::Job.count }.by(1)
    end

    it "exports pdf without payment_slip when payment_slip: false" do
      expect(Export::InvoicesJob).to receive(:new).with(:pdf, person.id, [invoice.id], hash_including(payment_slip: false)).and_call_original
      get :show, params: {group_id: group.id, id: invoice.id, payment_slip: false}, format: :pdf
    end

    it "exports pdf without articles when articles: false" do
      expect(Export::InvoicesJob).to receive(:new).with(:pdf, person.id, [invoice.id], hash_including(articles: false)).and_call_original
      get :show, params: {group_id: group.id, id: invoice.id, articles: false}, format: :pdf
    end

    it "exports pdf without reminders when reminders: false" do
      expect(Export::InvoicesJob).to receive(:new).with(:pdf, person.id, [invoice.id], hash_including(reminders: false)).and_call_original
      get :show, params: {group_id: group.id, id: invoice.id, reminders: false}, format: :pdf
    end

    it "exports csv" do
      get :show, params: {group_id: group.id, id: invoice.id}, format: :csv

      expect(response.header["Content-Disposition"]).to match(/Rechnung-#{invoice.sequence_number}.csv/)
      expect(response.media_type).to eq("text/csv")
    end

    it "renders json" do
      get :show, params: {group_id: group.id, id: invoice.id}, format: :json
      json = JSON.parse(response.body).deep_symbolize_keys
      expect(json[:invoices]).to have(1).items
      expect(json[:invoices].first[:total]).to eq "5.35"
      expect(json[:invoices].first[:links][:invoice_items]).to have(2).items

      expect(json[:linked][:groups]).to have(1).item
      expect(json[:linked][:groups].first[:id].to_i).to eq groups(:bottom_layer_one).id

      expect(json[:linked][:invoice_items]).to have(2).items

      expect(json[:links][:"invoices.creator"][:href]).to eq "http://test.host/people/{invoices.creator}.json"
      expect(json[:links][:"invoices.recipient"][:href]).to eq "http://test.host/people/{invoices.recipient}.json"
    end
  end

  context "DELETE#destroy" do
    it "moves invoice to cancelled state" do
      expect do
        delete :destroy, params: {group_id: group.id, id: invoice.id}
      end.not_to change { group.invoices.count }
      expect(invoice.reload.state).to eq "cancelled"
      expect(response).to redirect_to group_invoices_path(group)
      expect(flash[:notice]).to eq "Rechnung wurde storniert."
    end

    it "updates invoice_list" do
      list = InvoiceList.create(title: "List", group: group, invoices: [invoice, invoices(:sent)])

      list.update_total
      expect(list.recipients_total).to eq(2)
      expect(list.amount_total.to_f).to eq(5.85)

      invoice.reload

      expect do
        delete :destroy, params: {group_id: group.id, id: invoice.id}
      end.not_to change { group.invoices.count }
      expect(invoice.reload.state).to eq "cancelled"

      list.reload

      expect(list.recipients_total).to eq(1)
      expect(list.amount_total).to eq(0.5)
    end
  end

  context "post" do
    it "POST#create sets creator_id to current_user" do
      expect do
        post :create, params: {group_id: group.id, invoice: {title: "current_user", recipient_id: person.id}}
      end.to change { Invoice.count }.by(1)

      expect(Invoice.find_by(title: "current_user").creator).to eq(person)
    end

    it "POST#create allows to manually adjust the recipient address" do
      expect do
        post :create, params: {group_id: group.id, invoice: {title: "current_user", recipient_id: person.id, recipient_address: "Tim Testermann\nAlphastrasse 1\n8000 Zürich"}}
      end.to change { Invoice.count }.by(1)

      expect(Invoice.find_by(title: "current_user").recipient_address).to eq("Tim Testermann\nAlphastrasse 1\n8000 Zürich")
    end

    it "POST#create allows to manually adjust the recipient email" do
      expect do
        post :create, params: {group_id: group.id, invoice: {title: "current_user", recipient_id: person.id, recipient_email: "test@unit.com"}}
      end.to change { Invoice.count }.by(1)

      expect(Invoice.find_by(title: "current_user").recipient_email).to eq("test@unit.com")
    end

    it "POST#create accepts nested attributes for invoice_items" do
      expect do
        post :create, params: {
          group_id: group.id,
          invoice: {
            title: "current_user",
            recipient_id: person.id,
            invoice_items_attributes: {
              "1": {
                name: "pen",
                description: "simple pen",
                cost_center: "board",
                account: "advertisment",
                vat_rate: 0.0,
                unit_cost: 22.0,
                count: 1,
                _destroy: false
              }

            }
          }
        }
      end.to change { Invoice.count }.by(1)
      expect(assigns(:invoice).invoice_items).to have(1).entry
      expect(assigns(:invoice).invoice_items.first.cost_center).to eq "board"
      expect(assigns(:invoice).invoice_items.first.account).to eq "advertisment"
    end
  end

  def update_issued_at_to_current_year
    sent = invoices(:sent)
    if sent.issued_at.year != Time.zone.today.year
      sent.update(issued_at: Time.zone.today.beginning_of_year)
    end
  end
end
