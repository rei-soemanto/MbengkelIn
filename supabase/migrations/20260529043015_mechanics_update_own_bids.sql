create policy "Mechanics update own bids."
  on public.bids
  for update
  using (auth.uid() = provider_uid)
  with check (auth.uid() = provider_uid);
