export function secret(name:string){return process.env[name];}
export const url='https://jfaspsnqaujycpmfwvgv.supabase.co';
export const key='sb_publishable_GvQkRBJdFq1Luct5APmhjA_MgNUDTUY';
export async function authenticated(request:Request){const authorization=request.headers.get('authorization');if(!authorization?.startsWith('Bearer '))return null;const response=await fetch(`${url}/auth/v1/user`,{headers:{apikey:key,Authorization:authorization}});if(!response.ok)return null;const user=await response.json() as {id?:string};return user.id?{id:user.id,authorization}:null;}
