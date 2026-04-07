-- When an invitee accepts a playdate request, sync the parent playdates row.
-- Invitees cannot UPDATE playdates under typical RLS (organizer-only); this
-- trigger runs as the function owner and keeps status/participant_id consistent.

CREATE OR REPLACE FUNCTION public.sync_playdate_on_request_accepted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.status = 'accepted'
     AND (OLD.status IS DISTINCT FROM NEW.status) THEN
    UPDATE public.playdates
    SET
      status = 'confirmed',
      participant_id = NEW.invitee_id,
      updated_at = now()
    WHERE id = NEW.playdate_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_playdate_on_request_accepted ON public.playdate_requests;

CREATE TRIGGER trg_sync_playdate_on_request_accepted
  AFTER UPDATE OF status ON public.playdate_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_playdate_on_request_accepted();
