require 'typhoeus'
require 'json'

class ConfluenceApi

  attr_reader :base_url, :user, :pass

  # @param base_url [String] rest api url for confluence 
  #   e.g. https://localhost/confluence/rest/api
  # @param user [String] username for admin user
  # @param pass [String] corresponding password for user
  def initialize(base_url: nil, user: nil, pass: nil)
    @base_url= base_url
    @user= user
    @pass= pass
  end

  # Get pages in give space.
  #
  # @param space_key [String] key uniquely identifying confluence space
  def pages_in_space(space_key: nil)
    parameters = {
      limit: 1000,
      expand: 'children,ancestors'
    }
    target_url = @base_url + "/space/#{space_key}/content/page"
    resp = Typhoeus.get(target_url, params: parameters, userpwd: "#{@user}:#{@pass}")

    if resp.response_code == 200
      r = JSON.parse(resp.body)
      results = JSON.parse(resp.body)['results']
    end
  end

  # Get page given title and space key.
  #
  # @param page_title [String] title of page
  # @param space_key [String] key uniquely identifying confluence space
  def find_page_by_title(title: nil, space_key: nil)
    parameters = {
      title: title,
      spaceKey: space_key,
      expand: 'ancestors,version'
    }
    target_url = @base_url + "/content"

    resp = Typhoeus.get(target_url, params: parameters, userpwd: "#{@user}:#{@pass}")

    hsh = JSON.parse(resp.response_body)

    # Return a page hash or empty hash
    hsh['results'].first || Hash.new
  end

  # Create new page
  #
  # @param page_title [String] title of page
  # @param ancestor   [String] id of page that will be the parent of new page.
  # @param space_key  [String] key uniquely identifying confluence space
  # @param content    [String] xhtml content of the page
  def new_child_page(title: nil, ancestor_id: nil, space_key: nil, content: '')
    headers = {
      'Content-Type': 'application/json'
    }
    data = {
      type: 'page',
      title: title,
      ancestors: [{id: ancestor_id}],
      space: {key: space_key},
      body: {storage: {value: content, representation: "storage"}}
    }

    target_url = @base_url + "/content"
    resp = Typhoeus.post(target_url, body: data.to_json, headers: headers, userpwd: "#{@user}:#{@pass}")

    binding.pry

    resp.response_code
  end
  

  # Update existing page
  #
  # @param page      [Hash] page data
  # @param space_key [String] key uniquely identifying confluence space
  # @param content   [String] xhtml content of the page
  def update_page(page: {}, space_key: nil,  content: '')
    headers = {
      'Content-Type': 'application/json'
    }
    data = {
      id: page['id'],
      type: 'page',
      title: page['title'],
      space: {key: space_key},
      version: {number: page['version']['number'] + 1},
      body: {storage: {value: content, representation: "storage"}}
    }

    target_url = "#{@base_url}/content/#{page['id']}" 
    resp = Typhoeus.put(target_url, body: data.to_json, headers: headers, userpwd: "#{@user}:#{@pass}")
    resp.response_code
  end

  # Update or Create page
  #
  # @param title        [String] title of page
  # @param parent_title [String] title of page that will be the parent of new page.
  # @param space_key    [String] key uniquely identifying confluence space
  # @param content      [String] xhtml content of the page
  def update_or_create_page(title: nil, parent_title: nil, space_key: nil, content: '')
    page = find_page_by_title(title: title, space_key: space_key)
    if page.empty?
      puts "creating new page"
      parent_page = find_page_by_title(title: parent_title, space_key: Settings.space_key)
      return "No Parent: #{parent_title}" if parent_page.empty?
      result = new_child_page(title: name, ancestor_id: parent_page['id'], 
                         space_key: space_key, content: content)
    else
      puts "updating page"
      result = update_page(page: page, space_key: space_key, content: content)
    end
  end
end
