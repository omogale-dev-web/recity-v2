import { createClient } from '@supabase/supabase-js';
export const supabaseUrl = 'https://jfaspsnqaujycpmfwvgv.supabase.co';
export const publishableKey = 'sb_publishable_GvQkRBJdFq1Luct5APmhjA_MgNUDTUY';
export const supabase = createClient(supabaseUrl,publishableKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:false}});
