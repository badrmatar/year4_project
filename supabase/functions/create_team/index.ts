import { serve } from 'https://deno.land/std@0.175.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Environment Variables
const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 })
  }

  let body: any
  try {
    body = await req.json()
  } catch (error) {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), { status: 400 })
  }

  const { user_ids, league_room_id } = body

  // Validate input
  if (!Array.isArray(user_ids) || user_ids.length === 0 || !user_ids.every(id => typeof id === 'number')) {
    return new Response(JSON.stringify({ error: 'user_ids must be a non-empty array of numbers' }), { status: 400 })
  }

  if (typeof league_room_id !== 'number') {
    return new Response(JSON.stringify({ error: 'league_room_id must be a number' }), { status: 400 })
  }

  // Validate that the league_room_id exists
  const { data: leagueRoomData, error: leagueRoomError } = await supabase
    .from('league_rooms')
    .select('league_room_id')
    .eq('league_room_id', league_room_id)
    .single()

  if (leagueRoomError || !leagueRoomData) {
    return new Response(JSON.stringify({ error: 'Invalid league_room_id. League room not found.' }), { status: 400 })
  }

  // Fetch user names from the database
  const { data: usersData, error: usersError } = await supabase
    .from('users')
    .select('user_id, name')
    .in('user_id', user_ids)

  if (usersError) {
    return new Response(JSON.stringify({ error: usersError.message }), { status: 400 })
  }

  // Check if all requested users exist
  if (!usersData || usersData.length !== user_ids.length) {
    return new Response(JSON.stringify({ error: 'One or more user_ids are invalid' }), { status: 400 })
  }

  // Construct team_name by joining user names
  const names = usersData.map(u => u.name)
  const team_name = names.join(' & ')

  // Insert a new team with league_room_id
  const { data: teamData, error: teamError } = await supabase
    .from('teams')
    .insert({ team_name, league_room_id })
    .select('team_id')
    .single()

  if (teamError) {
    return new Response(JSON.stringify({ error: teamError.message }), { status: 400 })
  }

  const team_id = teamData.team_id

  // Insert memberships
  const dateJoined = new Date().toISOString().split('T')[0]
  const memberships = user_ids.map(uid => ({
    team_id,
    user_id: uid,
    date_joined: dateJoined
  }))

  const { error: membershipError } = await supabase
    .from('team_memberships')
    .insert(memberships)

  if (membershipError) {
    return new Response(JSON.stringify({ error: membershipError.message }), { status: 400 })
  }

  // Return the created team and memberships
  return new Response(JSON.stringify({
    team_id,
    team_name,
    league_room_id,
    members: user_ids
  }), { status: 201 })
})
