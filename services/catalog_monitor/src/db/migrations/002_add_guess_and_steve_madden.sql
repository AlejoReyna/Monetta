INSERT INTO sources (id, merchant, brand, base_url)
VALUES
  ('guess_us', 'GUESS', 'GUESS', 'https://www.guess.com'),
  ('steve_madden_us', 'Steve Madden', 'Steve Madden', 'https://www.stevemadden.com')
ON CONFLICT (id) DO UPDATE SET
  merchant = EXCLUDED.merchant,
  brand = EXCLUDED.brand,
  base_url = EXCLUDED.base_url;
