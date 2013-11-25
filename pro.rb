require "rubygems"
require "bundler"

Bundler.require(:default)

# > ruby http_proxy.rb
# > curl --proxy localhost:9889 www.google.com
# > curl --proxy x.x.x.x:9889 www.google.com - bind ip example

host = "0.0.0.0"
port = 9889
puts "listening on #{host}:#{port}..."

Proxy.start(:host => host, :port => port) do |conn|

  @p = Http::Parser.new
  @p.on_headers_complete = proc do |h|
    session = UUID.generate
    puts "New session: #{session} (#{h.inspect})"

    host, port = h['Host'].split(':')
    # Don't fwd curl requests
    unless h["User-Agent"] =~ /curl/i
      conn.server session, :host => host, :port => (port || 80) #, :bind_host => conn.sock[0] - # for bind ip

      conn.relay_to_servers @buffer

      @buffer.clear
    else
      puts "Not forwarding #{h["User-Agent"]}"
      data = <<-EOF
HTTP/1.1 400 Bad Request
Date: #{DateTime.now.httpdate}
Server: EM-Proxy
Connection: close
Content-Type: text/html; charset=iso-8859-1

<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<HTML><HEAD>
<TITLE>400 Bad Request</TITLE>
</HEAD><BODY>
<H1>Bad Request</H1>
Your browser sent a request that this server could not understand.<P>
The request line contained invalid characters following the protocol string.<P><P>
</BODY></HTML>
      EOF
      conn.send_data(data)
      conn.close_connection(true)
    end
  end

  @buffer = ''

  conn.on_connect do |data,b|
    puts [:on_connect, data, b].inspect
  end

  conn.on_data do |data|
    @buffer << data
    @p << data

    data
  end

  conn.on_response do |backend, resp|
    puts [:on_response, backend, resp].inspect
    resp
  end

  conn.on_finish do |backend, name|
    puts [:on_finish, name].inspect
  end
end


