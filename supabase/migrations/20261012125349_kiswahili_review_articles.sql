-- Kiswahili review of the Learn articles (reviewer: Rajula Bonum, 12 Oct 2026).
-- 54 of 57 parts were approved as they were. Two corrections are applied here;
-- the third flagged part (Box breathing, paragraph 2) had no suggestion yet.

update public.resources
set body_sw = replace(
      body_sw,
      'Usiku kabla ya mtihani, acha kusoma mapema na ulale.',
      'Usiku kabla ya mtihani, maliza masomo mapema kisha ulale kwa wakati ufaao.'),
    updated_at = now()
where title_en = 'Exam stress: a survival plan';

update public.resources
set body_sw = replace(
      body_sw,
      'kumfikia kunaweza kuleta tofauti kubwa.',
      'kumjulia hali kunaweza kuleta tofauti kubwa.'),
    updated_at = now()
where title_en = 'Helping a friend who is struggling';
