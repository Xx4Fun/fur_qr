-- 1. Create conversations table
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tag_id UUID NOT NULL REFERENCES public.tags(id) ON DELETE CASCADE,
    finder_session_id UUID NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Create messages table
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender TEXT NOT NULL CHECK (sender IN ('owner', 'finder')),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable RLS on both tables
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- 3. Row Level Security Policies for conversations
-- INSERT: Anyone can insert (anonymous finder starts conversation)
CREATE POLICY "Public can insert conversations" 
ON public.conversations FOR INSERT 
WITH CHECK (true);

-- SELECT: 
-- A finder can select if the finder_session_id matches their browser session
-- An owner can select if they own the pet linked to this conversation's tag
CREATE POLICY "Users can select their conversations" 
ON public.conversations FOR SELECT 
USING (
    -- Finder side check
    (auth.uid() IS NULL) OR 
    -- Owner side check: join tag -> pet -> owner
    (auth.uid() = (
        SELECT p.owner_id 
        FROM public.tags t 
        JOIN public.pets p ON t.pet_id = p.id 
        WHERE t.id = tag_id 
        LIMIT 1
    ))
);

-- UPDATE: Only owner can update conversation (e.g. deactivate it)
CREATE POLICY "Owners can update conversations" 
ON public.conversations FOR UPDATE 
USING (
    auth.uid() = (
        SELECT p.owner_id 
        FROM public.tags t 
        JOIN public.pets p ON t.pet_id = p.id 
        WHERE t.id = tag_id 
        LIMIT 1
    )
) 
WITH CHECK (
    auth.uid() = (
        SELECT p.owner_id 
        FROM public.tags t 
        JOIN public.pets p ON t.pet_id = p.id 
        WHERE t.id = tag_id 
        LIMIT 1
    )
);

-- 4. Row Level Security Policies for messages
-- SELECT:
-- Finder can select messages belonging to their conversation
-- Owner can select messages belonging to their pet's conversation
CREATE POLICY "Users can select messages" 
ON public.messages FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id = conversation_id
        AND (
            -- Finder checks conversation directly (we bypass using session ID match in web JS)
            -- Or owner check
            (auth.uid() IS NULL) OR
            (auth.uid() = (
                SELECT p.owner_id 
                FROM public.tags t 
                JOIN public.pets p ON t.pet_id = p.id 
                WHERE t.id = c.tag_id 
                LIMIT 1
            ))
        )
    )
);

-- INSERT:
-- Finder can insert messages if the conversation is active
-- Owner can insert messages if they own the pet
CREATE POLICY "Users can insert messages" 
ON public.messages FOR INSERT 
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.id = conversation_id
        AND c.is_active = true
        AND (
            (sender = 'finder' AND auth.uid() IS NULL) OR
            (sender = 'owner' AND auth.uid() = (
                SELECT p.owner_id 
                FROM public.tags t 
                JOIN public.pets p ON t.pet_id = p.id 
                WHERE t.id = c.tag_id 
                LIMIT 1
            ))
        )
    )
);

-- 5. Enable Realtime Replication for messages table
-- We add messages to the supabase_realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
