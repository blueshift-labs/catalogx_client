module HTTPStatusCodes
  OK = 200
  CREATED = 201
  NO_CONTENT = 204
  PARTIAL_CONTENT = 206

  def self.success_codes
    Set.new([
      OK,
      CREATED,
      NO_CONTENT,
      PARTIAL_CONTENT
    ])
  end
end
