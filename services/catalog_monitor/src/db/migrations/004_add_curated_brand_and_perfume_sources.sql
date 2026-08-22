INSERT INTO sources (id, merchant, brand, base_url)
VALUES
  ('marc_jacobs_us', 'Marc Jacobs', 'Marc Jacobs', 'https://www.marcjacobs.com'),
  ('tory_burch_us', 'Tory Burch', 'Tory Burch', 'https://www.toryburch.com'),
  ('kate_spade_us', 'Kate Spade', 'Kate Spade', 'https://www.katespade.com'),
  ('guess_factory_us', 'GUESS Factory', 'GUESS Factory', 'https://www.guessfactory.com'),
  ('gp_mcallen_perfumes', 'Gold Palace McAllen', 'Perfumes', 'https://www.gpmcallen.com')
ON CONFLICT (id) DO UPDATE SET
  merchant = EXCLUDED.merchant,
  brand = EXCLUDED.brand,
  base_url = EXCLUDED.base_url;
