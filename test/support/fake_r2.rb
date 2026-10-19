require "socket"

# A stand-in for Cloudflare R2 on 127.0.0.1: records every request it gets
# and answers with the given status. Point R2_ENDPOINT at #endpoint.
class FakeR2
  attr_reader :requests

  def initialize(status: 200)
    @status = status
    @requests = []
    @server = TCPServer.new("127.0.0.1", 0)
    @thread = Thread.new { serve }
  end

  def endpoint
    "http://127.0.0.1:#{@server.addr[1]}"
  end

  def env
    {
      "R2_ACCOUNT_ID" => "test-account", "R2_ACCESS_KEY_ID" => "TESTKEY",
      "R2_SECRET_ACCESS_KEY" => "test-secret", "R2_BUCKET" => "tmc-backups", "R2_ENDPOINT" => endpoint
    }
  end

  def stop
    @server.close
    @thread.join(1)
  end

  private

  def serve
    loop { handle(@server.accept) }
  rescue IOError, Errno::EBADF
    nil
  end

  def handle(client)
    method, path = client.gets.to_s.split
    headers = {}
    while (line = client.gets) && line != "\r\n"
      name, value = line.split(":", 2)
      headers[name.strip.downcase] = value.to_s.strip
    end
    body = client.read(headers["content-length"].to_i)
    @requests << { method: method, path: path, headers: headers, body: body }
    client.write("HTTP/1.1 #{@status} Fake\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
  ensure
    client.close
  end
end

module EnvHelper
  def with_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
