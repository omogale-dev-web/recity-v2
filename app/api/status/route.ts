import {secret} from '@/lib/server';
export async function GET(){return Response.json({ai:!!secret('GROQ_API_KEY'),databaseConfigured:!!secret('SUPABASE_SECRET_KEY'),push:false});}
