-- Aggregated feed snapshot RPC for BarkDate
-- Provides near-instant feed hydration with a single call
-- Generated on 2025-10-19

CREATE OR REPLACE FUNCTION get_feed_snapshot(
  p_user_id uuid,
  p_radius_km integer DEFAULT NULL,
  p_limit_nearby integer DEFAULT 20,
  p_limit_events integer DEFAULT 10,
  p_limit_friends integer DEFAULT 20
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_latitude double precision;
  v_longitude double precision;
  v_radius integer;
  v_primary_dog uuid;
  v_nearby jsonb := '[]'::jsonb;
  v_playdates jsonb := '[]'::jsonb;
  v_my_events jsonb := '[]'::jsonb;
  v_suggested_events jsonb := '[]'::jsonb;
  v_friends jsonb := '[]'::jsonb;
  v_meta jsonb := '{}'::jsonb;
  v_playdate_dog_ids jsonb := '[]'::jsonb;
  v_event_dog_ids jsonb := '[]'::jsonb;
  v_counts jsonb := '{}'::jsonb;
  v_checkin jsonb := '{}'::jsonb;
  v_upcoming_count integer := 0;
  v_unread_count integer := 0;
  v_mutual_count integer := 0;
  v_has_active_checkin boolean := false;
BEGIN
  -- Resolve user location and radius preferences
  SELECT latitude, longitude, COALESCE(search_radius_km, 25)
    INTO v_latitude, v_longitude, v_radius
  FROM users
  WHERE id = p_user_id;

  IF p_radius_km IS NOT NULL THEN
    v_radius := p_radius_km;
  END IF;

  -- Resolve primary dog (first active dog)
  SELECT id
    INTO v_primary_dog
  FROM dogs
  WHERE user_id = p_user_id
    AND is_active = TRUE
  ORDER BY created_at ASC
  LIMIT 1;

  -- Nearby dogs (location required)
  IF v_latitude IS NOT NULL AND v_longitude IS NOT NULL THEN
    SELECT COALESCE(jsonb_agg(to_jsonb(nd)), '[]'::jsonb)
      INTO v_nearby
    FROM get_nearby_dogs(
      p_user_id,
      v_latitude,
      v_longitude,
      v_radius,
      p_limit_nearby,
      0
    ) AS nd;
  END IF;

  -- Upcoming playdates (confirmed only)
  WITH upcoming AS (
    SELECT DISTINCT p.id,
           p.title,
           p.location,
           p.scheduled_at,
           p.status
    FROM playdates p
    LEFT JOIN playdate_participants pp
      ON pp.playdate_id = p.id
    WHERE (p.organizer_id = p_user_id OR pp.user_id = p_user_id)
      AND p.status = 'confirmed'
      AND p.scheduled_at >= NOW()
    ORDER BY p.scheduled_at ASC
    LIMIT p_limit_events
  )
  SELECT COALESCE(jsonb_agg(to_jsonb(upcoming)), '[]'::jsonb)
    INTO v_playdates
  FROM upcoming;

  -- Track dog IDs with upcoming playdates
  WITH playdate_dogs AS (
    SELECT DISTINCT pp.dog_id
    FROM playdate_participants pp
    JOIN playdates p ON p.id = pp.playdate_id
    WHERE p.id IN (SELECT (value->>'id')::uuid FROM jsonb_array_elements(v_playdates))
  )
  SELECT COALESCE(jsonb_agg(to_jsonb(playdate_dogs.dog_id)), '[]'::jsonb)
    INTO v_playdate_dog_ids
  FROM playdate_dogs;

  -- Events the user is participating in
  WITH participating AS (
    SELECT e.*, u.name AS organizer_name, u.avatar_url AS organizer_avatar_url
    FROM event_participants ep
    JOIN events e ON e.id = ep.event_id
    LEFT JOIN users u ON u.id = e.organizer_id
    WHERE ep.user_id = p_user_id
    ORDER BY e.start_time ASC
    LIMIT p_limit_events
  )
  SELECT COALESCE(jsonb_agg(
           to_jsonb(participating) ||
           jsonb_build_object(
             'photo_urls', COALESCE(participating.photo_urls, '{}'::text[])
           )
         ), '[]'::jsonb)
    INTO v_my_events
  FROM participating;

  -- Dogs participating in these events
  WITH event_dogs AS (
    SELECT DISTINCT ep.dog_id
    FROM event_participants ep
    WHERE ep.event_id IN (SELECT (value->>'id')::uuid FROM jsonb_array_elements(v_my_events))
  )
  SELECT COALESCE(jsonb_agg(to_jsonb(event_dogs.dog_id)), '[]'::jsonb)
    INTO v_event_dog_ids
  FROM event_dogs;

  -- Suggested public events near user
  IF v_latitude IS NOT NULL AND v_longitude IS NOT NULL THEN
    WITH suggested AS (
      SELECT e.*, u.name AS organizer_name, u.avatar_url AS organizer_avatar_url
      FROM events e
      LEFT JOIN users u ON u.id = e.organizer_id
      WHERE e.status = 'upcoming'
        AND e.start_time >= NOW()
        AND e.latitude IS NOT NULL
        AND e.longitude IS NOT NULL
        AND ST_DWithin(
          ST_MakePoint(v_longitude, v_latitude)::geography,
          ST_MakePoint(e.longitude, e.latitude)::geography,
          50000
        )
        AND NOT EXISTS (
          SELECT 1
          FROM event_participants ep
          WHERE ep.event_id = e.id
            AND ep.user_id = p_user_id
        )
      ORDER BY e.start_time ASC
      LIMIT p_limit_events
    )
    SELECT COALESCE(jsonb_agg(
             to_jsonb(suggested) ||
             jsonb_build_object(
               'photo_urls', COALESCE(suggested.photo_urls, '{}'::text[])
             )
           ), '[]'::jsonb)
      INTO v_suggested_events
    FROM suggested;
  END IF;

  -- Friends (dog friendships)
  IF v_primary_dog IS NOT NULL THEN
    WITH friendships AS (
      SELECT df.id,
             df.dog1_id,
             df.dog2_id,
             df.friendship_level,
             df.created_at,
             CASE WHEN df.dog1_id = v_primary_dog THEN df.dog2_id ELSE df.dog1_id END AS friend_dog_id
      FROM dog_friendships df
      WHERE df.dog1_id = v_primary_dog OR df.dog2_id = v_primary_dog
      ORDER BY df.created_at DESC
      LIMIT p_limit_friends
    ),
    friend_profiles AS (
      SELECT f.id,
             f.friendship_level,
             d.id AS dog_id,
             d.name AS dog_name,
             d.main_photo_url,
             d.breed,
             d.age,
             u.id AS owner_id,
             u.name AS owner_name,
             u.avatar_url
      FROM friendships f
      JOIN dogs d ON d.id = f.friend_dog_id
      LEFT JOIN users u ON u.id = d.user_id
    )
    SELECT COALESCE(jsonb_agg(
             jsonb_build_object(
               'friendship_level', fp.friendship_level,
               'friend_dog', jsonb_build_object(
                 'id', fp.dog_id,
                 'name', fp.dog_name,
                 'main_photo_url', fp.main_photo_url,
                 'breed', fp.breed,
                 'age', fp.age,
                 'owner', jsonb_build_object(
                   'id', fp.owner_id,
                   'name', fp.owner_name,
                   'avatar_url', fp.avatar_url
                 )
               )
             )
           ), '[]'::jsonb)
      INTO v_friends
    FROM friend_profiles fp;
  END IF;

  -- Counters
  SELECT COUNT(*) INTO v_upcoming_count
  FROM playdates p
  LEFT JOIN playdate_participants pp ON pp.playdate_id = p.id
  WHERE (p.organizer_id = p_user_id OR pp.user_id = p_user_id)
    AND p.status = 'confirmed'
    AND p.scheduled_at >= NOW();

  SELECT COUNT(*) INTO v_unread_count
  FROM notifications
  WHERE user_id = p_user_id
    AND is_read = FALSE;

  SELECT COUNT(*) INTO v_mutual_count
  FROM matches
  WHERE user_id = p_user_id
    AND is_mutual = TRUE
    AND action = 'bark';

  SELECT EXISTS (
    SELECT 1 FROM checkins
    WHERE user_id = p_user_id
      AND status = 'active'
  ) INTO v_has_active_checkin;

  v_counts := jsonb_build_object(
    'upcoming_playdates', v_upcoming_count,
    'unread_notifications', v_unread_count,
    'mutual_barks', v_mutual_count
  );

  v_checkin := jsonb_build_object('has_active', v_has_active_checkin);

  v_meta := jsonb_build_object(
    'playdate_dog_ids', v_playdate_dog_ids,
    'event_dog_ids', v_event_dog_ids
  );

  RETURN jsonb_build_object(
    'user_id', p_user_id,
    'primary_dog_id', v_primary_dog,
    'nearby_dogs', v_nearby,
    'upcoming_playdates', v_playdates,
    'my_events', v_my_events,
    'suggested_events', v_suggested_events,
    'friends', v_friends,
    'counters', v_counts,
    'checkin', v_checkin,
    'meta', v_meta
  );
END;
$$;
