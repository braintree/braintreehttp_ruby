require 'stringio'
require 'zlib'

require_relative './serializers/json'
require_relative './serializers/form_encoded'
require_relative './serializers/text'
require_relative './serializers/multipart'

module BraintreeHttp
  class Encoder
    def initialize
      @encoders = [Json.new, Text.new, Multipart.new, FormEncoded.new]
    end

    def serialize_request(req)
      raise UnsupportedEncodingError.new('HttpRequest did not have Content-Type header set') unless req.headers && (req.headers['content-type'] || req.headers['Content-Type'])

      content_type = _extract_header(req.headers, 'Content-Type')

      enc = _encoder(content_type)
      raise UnsupportedEncodingError.new("Unable to serialize request with Content-Type #{content_type}. Supported encodings are #{supported_encodings}") unless enc

      encoded = enc.encode(req)
      content_encoding = _extract_header(req.headers, 'Content-Encoding')

      if content_encoding == 'gzip'
        out = StringIO.new('w')
        writer = Zlib::GzipWriter.new(out)

        writer.write encoded
        writer.close

        encoded = out.string
      end

      encoded
    end

    def deserialize_response(resp, headers)
      raise UnsupportedEncodingError.new('HttpResponse did not have Content-Type header set') unless headers && (headers['content-type'] || headers['Content-Type'])

      content_type = _extract_header(headers, 'Content-Type')

      enc = _encoder(content_type)
      raise UnsupportedEncodingError.new("Unable to deserialize response with Content-Type #{content_type}. Supported decodings are #{supported_encodings}") unless enc

      content_encoding = _extract_header(headers, 'Content-Encoding')

      if content_encoding == 'gzip'
        buf = StringIO.new(resp, 'rb')
        reader = Zlib::GzipReader.new(buf)

        resp = reader.read
      end

      enc.decode(resp)
    end

    def supported_encodings
      @encoders.map { |enc| enc.content_type.inspect }
    end

    def _encoder(content_type)
      idx = @encoders.index { |enc| enc.content_type.match(content_type) }

      @encoders[idx] if idx
    end

    def _extract_header(headers, key)
      value = headers[key] || headers[key.downcase]
      value = value.first if value.kind_of?(Array)

      value
    end
  end
end
