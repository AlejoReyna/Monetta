# Shopify's mobile ID tokens can carry a positive integer `sub`. AppAuth 2.0.0
# otherwise discards that claim because OIDIDToken expects NSString, then fails
# with OIDErrorCodeIDTokenParsingError (-14). Normalize only the parsed subject;
# the JWT and AppAuth's issuer/audience/expiry/nonce validation stay intact.
module MonettaAppAuthNumericSubject
  ORIGINAL = <<~'OBJC'.freeze
    fieldMap[kSubKey] =
        [[OIDFieldMapping alloc] initWithName:@"_subject" type:[NSString class]];
  OBJC

  REPLACEMENT = <<~'OBJC'.freeze
    fieldMap[kSubKey] =
        [[OIDFieldMapping alloc] initWithName:@"_subject"
                                         type:[NSString class]
                                   conversion:^id _Nullable(NSObject *_Nullable value) {
          // Monetta: preserve Shopify's integer customer subject exactly.
          if ([value isKindOfClass:[NSNumber class]] &&
              CFGetTypeID((__bridge CFTypeRef)value) != CFBooleanGetTypeID() &&
              !CFNumberIsFloatType((__bridge CFNumberRef)(NSNumber *)value) &&
              [(NSNumber *)value longLongValue] > 0) {
            return [(NSNumber *)value stringValue];
          }
          return value;
        }];
  OBJC

  def self.apply(source_path, version:)
    raise "Review the numeric-subject patch for AppAuth #{version}" unless version == '2.0.0'

    source = File.read(source_path)
    original = ORIGINAL.lines.map { |line| "    #{line}" }.join
    replacement = REPLACEMENT.lines.map { |line| "    #{line}" }.join
    return if source.include?(replacement)

    unless source.scan(original).length == 1
      raise 'AppAuth OIDIDToken changed; review the numeric-subject patch before building'
    end

    File.chmod(File.stat(source_path).mode | 0o200, source_path)
    File.write(source_path, source.sub(original, replacement))
  end
end
