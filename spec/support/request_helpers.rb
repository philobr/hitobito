module RequestHelpers 
  extend ActiveSupport::Concern
  
  def sign_in(user = nil)
    user ||= people(:top_leader)
    visit person_session_path
    fill_in 'Email', with: user.email
    fill_in 'Passwort', with: 'foobar'
    click_button 'Anmelden'
  end

  # not now
  private
  def set_basic_auth(name, password)
    if page.driver.respond_to?(:basic_auth)
      page.driver.basic_auth(name, password)
    elsif page.driver.respond_to?(:basic_authorize)
      page.driver.basic_authorize(name, password)
    elsif page.driver.respond_to?(:browser) && page.driver.browser.respond_to?(:basic_authorize)
      page.driver.browser.basic_authorize(name, password)
    elsif page.driver.class == Capybara::Poltergeist::Driver
      encoded = Base64.encode64("#{name}:#{password}").strip
      page.driver.headers = { "Authorization" => "Basic #{encoded}" } 
    else
      raise "I don't know how to set basic auth!"
    end
  end

  def obsolete_node_safe
    begin
      yield
    rescue Capybara::Poltergeist::ObsoleteNode => e
      pending
    end
  end

end
