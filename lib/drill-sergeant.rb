require "json"
require "net/http"
require "drill/version"

class Drill
  class Error < StandardError; end

  HEADERS = {
    "Content-Type" => "application/json",
    "Accept" => "application/json"
  }

  def initialize(url: nil, open_timeout: 3, read_timeout: nil)
    url ||= ENV["DRILL_URL"] || "http://localhost:8047"
    @uri = URI.parse(url)
    @http = Net::HTTP.new(@uri.host, @uri.port)
    @http.use_ssl = true if @uri.scheme == "https"
    @http.open_timeout = open_timeout if open_timeout
    @http.read_timeout = read_timeout if read_timeout
  end

  def query(statement)
    data = {
      queryType: "sql",
      query: statement
    }

    body = post("/query.json", data)

    if body["errorMessage"]
      raise Drill::Error, body["errorMessage"].split("\n")[0]
    end

    # return columns in order
    result = []
    columns = body["columns"]
    body["rows"].each do |row|
      result << columns.each_with_object({}) { |c, memo| memo[c] = row[c] }
    end
    result
  end

  def profiles
    get("/profiles.json")
  end

  def storage
    get("/storage.json")
  end

  def cluster
    get("/cluster.json")
  end

  def options
    get("/options.json")
  end

  private

  def get(path)
    handle_response do
      @http.get(path, HEADERS)
    end
  end

  def post(path, data)
    handle_response do
      @http.post(path, data.to_json, HEADERS)
    end
  end

  def handle_response
    begin
      response = yield
    rescue Errno::ECONNREFUSED => e
      raise Drill::Error, e.message
    end

    JSON.parse(response.body)
  end
end
