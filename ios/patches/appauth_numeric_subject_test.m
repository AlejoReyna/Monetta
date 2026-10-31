#import <Foundation/Foundation.h>
#import "OIDIDToken.h"

static NSString *segment(NSDictionary *value) {
  NSData *data = [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
  NSString *encoded = [data base64EncodedStringWithOptions:0];
  encoded = [encoded stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
  encoded = [encoded stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
  return [encoded stringByReplacingOccurrencesOfString:@"=" withString:@""];
}

static OIDIDToken *parse(NSDictionary *claims) {
  NSString *jwt = [NSString stringWithFormat:@"%@.%@.test-signature",
      segment(@{@"alg": @"RS256"}), segment(claims)];
  return [[OIDIDToken alloc] initWithIDTokenString:jwt];
}

static void check(BOOL condition, NSString *message) {
  if (!condition) {
    fprintf(stderr, "%s\n", [message UTF8String]);
    exit(1);
  }
}

int main(void) {
  @autoreleasepool {
    NSDictionary *valid = @{
      @"iss": @"https://shopify.com/authentication/90228850722",
      @"sub": @9876543210123LL,
      @"aud": @"test-client",
      @"exp": @2000000000,
      @"iat": @1900000000,
      @"nonce": @"test-nonce",
    };
    OIDIDToken *numeric = parse(valid);
    check([numeric.subject isEqualToString:@"9876543210123"],
          @"A numeric Shopify customer subject must parse without losing digits");
    check([numeric.claims[@"sub"] isEqual:valid[@"sub"]],
          @"The original token claims must remain unchanged");
    check([numeric.audience isEqual:@[@"test-client"]] &&
          [numeric.nonce isEqualToString:@"test-nonce"] &&
          [numeric.issuer.absoluteString isEqualToString:valid[@"iss"]] &&
          numeric.expiresAt.timeIntervalSince1970 == 2000000000 &&
          numeric.issuedAt.timeIntervalSince1970 == 1900000000,
          @"The claims AppAuth validates must remain intact");

    NSMutableDictionary *claims = [valid mutableCopy];
    claims[@"sub"] = @"gid://shopify/Customer/123";
    check([parse(claims).subject isEqualToString:claims[@"sub"]],
          @"Existing string subjects must continue to work");
    for (id invalid in @[@YES, @1.5, @0, @(-1), @[], [NSNull null]]) {
      claims[@"sub"] = invalid;
      check(parse(claims) == nil, @"Unsupported subject types must still fail");
    }
    for (NSString *required in @[@"iss", @"sub", @"aud", @"exp", @"iat"]) {
      claims = [valid mutableCopy];
      [claims removeObjectForKey:required];
      check(parse(claims) == nil, @"Missing required claims must still fail");
    }
    puts("PASS: AppAuth numeric subject compatibility and required claims");
  }
  return 0;
}
