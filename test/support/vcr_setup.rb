require "vcr"

VCR.configure do |config|
  config.hook_into :webmock
  config.register_request_matcher :body_without_random_ref_id do |request_1, request_2|
    body1, body2 = request_1.body, request_2.body
    ref_id_regex = /"ref_id":"[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}"/i
    body1_without_ref_id = body1.gsub(ref_id_regex, "ref_id":"00000000-0000-4000-b0000-000000000000")
    body2_without_ref_id = body2.gsub(ref_id_regex, "ref_id":"00000000-0000-4000-b0000-000000000000")
    body1_without_ref_id == body2_without_ref_id
  end
end
