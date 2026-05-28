import { createClient } from 'npm:@supabase/supabase-js@2';

const SUPABASE_URL = 'https://lioqpvbitlobracvkttp.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxpb3FwdmJpdGxvYnJhY3ZrdHRwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk1NDUyNzYsImV4cCI6MjA5NTEyMTI3Nn0.7P3aGsYA7i8jU6xFzmZnmgVj_Acj0YD-JGSK9KeTCk8';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function test() {
    const { data, error } = await supabase
        .from('tags')
        .select(`
            id,
            is_active,
            pets (
                name,
                photo_url,
                public_notes
            )
        `)
        .eq('id', '9876902b-e146-4e97-90f6-0798823c1c84')
        .single();
        
    console.log("Data:", data);
    console.log("Error:", error);
}

test();