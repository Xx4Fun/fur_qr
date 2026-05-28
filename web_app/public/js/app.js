document.addEventListener('DOMContentLoaded', async () => {
    const urlParams = new URLSearchParams(window.location.search);
    const tagId = urlParams.get('id');

    const loadingEl = document.getElementById('loading');
    const errorEl = document.getElementById('error-state');
    const mainGrid = document.getElementById('main-grid');
    
    if (!tagId) {
        showError("No tag ID provided in the URL. (URL: " + window.location.href + ")");
        return;
    }

    let currentPet = null;

    try {
        const { data: tagData, error } = await supabaseClient
            .from('tags')
            .select(`
                id,
                is_active,
                pets (
                    name,
                    photo_url,
                    public_notes,
                    attributes,
                    owners (
                        full_name,
                        phone_number,
                        avatar_url
                    )
                )
            `)
            .eq('id', tagId)
            .single();

        if (error || !tagData) {
            console.error(error);
            showError("Tag not found: " + (error ? error.message : "Empty response") + " (tagId: " + tagId + ")");
            return;
        }

        if (!tagData.is_active) {
            showError("This tag is currently inactive. (tagId: " + tagId + ")");
            return;
        }

        currentPet = tagData.pets;
        renderPet(currentPet);
        
        // Show main content container grid
        mainGrid.classList.remove('hidden');
        loadingEl.classList.add('hidden');

        // Location & Contact Activation Flow
        handleLocationFlow(tagId, currentPet.owners);
        // Setup Chat Interactions
        setupChatInteractions(currentPet.owners);

    } catch (err) {
        console.error(err);
        showError("An unexpected error occurred: " + err.message + " (URL: " + window.location.href + ")");
    }

    function renderPet(pet) {
        // Name
        document.getElementById('pet-name').innerText = pet.name || "Unknown Pet";
        
        // Medical Notes
        const notesEl = document.getElementById('pet-notes');
        if (pet.attributes && pet.attributes.medical_notes && pet.attributes.medical_notes.trim() !== '') {
            notesEl.innerText = pet.attributes.medical_notes;
        } else if (pet.public_notes && pet.public_notes.trim() !== '') {
            notesEl.innerText = pet.public_notes.replace(/Medical: /g, '').split('\n')[0];
        } else {
            notesEl.innerText = "No special medical details registered.";
        }

        // Behavior Notes / Markings
        const behaviorEl = document.getElementById('pet-behavior');
        if (pet.attributes && pet.attributes.markings && pet.attributes.markings.trim() !== '') {
            behaviorEl.innerText = pet.attributes.markings;
        } else if (pet.public_notes && pet.public_notes.includes('Markings:')) {
            behaviorEl.innerText = pet.public_notes.split('Markings: ')[1] || "No markings listed.";
        } else {
            behaviorEl.innerText = "Friendly but might be frightened. Speak softly.";
        }

        // Attributes Grid
        if (pet.attributes) {
            document.getElementById('pet-breed').innerText = pet.attributes.breed || "N/A";
            document.getElementById('pet-age').innerText = pet.attributes.age || "N/A";
            document.getElementById('pet-gender').innerText = pet.attributes.gender || "N/A";
            document.getElementById('pet-weight').innerText = pet.attributes.weight || "N/A";
        }

        // Photo
        const photoEl = document.getElementById('pet-photo');
        const noPhotoEl = document.getElementById('no-photo');
        if (pet.photo_url) {
            photoEl.src = pet.photo_url;
            photoEl.classList.remove('hidden');
        } else {
            noPhotoEl.classList.remove('hidden');
        }

        // Owner Info (Class-based selector because Owner Cards are duplicated for mobile & desktop layouts)
        if (pet.owners) {
            document.querySelectorAll('.owner-name').forEach(el => {
                el.innerText = pet.owners.full_name || "Unknown Owner";
            });
            if (pet.owners.avatar_url) {
                document.querySelectorAll('.owner-photo').forEach(el => {
                    el.src = pet.owners.avatar_url;
                    el.classList.remove('hidden');
                });
                document.querySelectorAll('.owner-no-photo').forEach(el => {
                    el.classList.add('hidden');
                });
            }
        }
    }

    function showError(message) {
        loadingEl.classList.add('hidden');
        document.getElementById('error-message').innerText = message;
        errorEl.classList.remove('hidden');
    }

    async function handleLocationFlow(tagId, owner) {
        const notifySection = document.getElementById('notify-section');
        const locationSharedSection = document.getElementById('location-shared-section');
        const notifyBtn = document.getElementById('notify-btn');
        const btnCallOwner = document.getElementById('btn-call-owner');
        
        // Setup owner call buttons (phone number links)
        if (owner && owner.phone_number) {
            btnCallOwner.href = `tel:${owner.phone_number}`;
            document.querySelectorAll('.btn-call-owner-icon').forEach(el => {
                el.href = `tel:${owner.phone_number}`;
            });
        }

        // Function to reveal contact options and owner card
        const revealOwnerContacts = () => {
            notifySection.classList.add('hidden');
            locationSharedSection.classList.remove('hidden');
            document.querySelectorAll('.owner-info-card').forEach(el => {
                el.classList.remove('hidden');
                el.classList.add('flex');
            });
        };

        // Attempt to request location instantly on load
        try {
            const position = await new Promise((resolve, reject) => {
                if (!navigator.geolocation) {
                    reject(new Error("Geolocation unsupported"));
                    return;
                }
                navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 3000 });
            });

            // Location coordinates granted
            const lat = position.coords.latitude;
            const lng = position.coords.longitude;
            
            // Invoke Supabase Edge Function to notify owner
            await notifyOwnerApi(tagId, lat, lng);
            document.getElementById('pet-location').innerText = "Location shared";
            revealOwnerContacts();

        } catch (error) {
            // Geolocation blocked or timed out
            document.getElementById('pet-location').innerText = "Location not shared";
            
            // Wait for finder to click the "Notify Owner I Found Them!" button
            notifyBtn.addEventListener('click', async () => {
                notifyBtn.disabled = true;
                notifyBtn.classList.add('opacity-75', 'cursor-not-allowed');
                const originalText = notifyBtn.innerHTML;
                notifyBtn.innerText = "Sending Alert...";

                let lat = null;
                let lng = null;

                try {
                    // Prompt for location access one more time
                    const pos = await new Promise((resolve) => {
                        navigator.geolocation.getCurrentPosition(resolve, () => resolve(null), { timeout: 5000 });
                    });
                    if (pos) {
                        lat = pos.coords.latitude;
                        lng = pos.coords.longitude;
                        document.getElementById('pet-location').innerText = "Location shared";
                    }
                } catch (e) {}

                try {
                    await notifyOwnerApi(tagId, lat, lng);
                    if (!lat) {
                        document.getElementById('location-msg').innerText = "Owner notified! We couldn't fetch your exact location, but they know their pet was found.";
                    }
                    revealOwnerContacts();
                } catch (err) {
                    console.error(err);
                    alert("Unable to reach the owner. Please verify your connection.");
                    notifyBtn.disabled = false;
                    notifyBtn.classList.remove('opacity-75', 'cursor-not-allowed');
                    notifyBtn.innerHTML = originalText;
                }
            });
        }
    }

    async function notifyOwnerApi(tagId, lat, lng) {
        const { data, error } = await supabaseClient.functions.invoke('notify-owner', {
            body: { tag_id: tagId, lat: lat, lng: lng }
        });

        if (error) {
            if (error.context && error.context.status === 429) {
                // Rate limited but acceptable from finder perspective (still means notification processing is running)
                return; 
            }
            throw new Error("API Notification error");
        }
    }

    function setupChatInteractions(owner) {
        const btnMessageOwner = document.getElementById('btn-message-owner');
        const chatModal = document.getElementById('chat-modal');
        const btnCloseChat = document.getElementById('btn-close-chat');
        const chatInput = document.getElementById('chat-input');
        const btnSendMessage = document.getElementById('btn-send-message');
        const chatMessages = document.getElementById('chat-messages');

        let activeConversation = null;
        let realtimeSubscription = null;

        // Generate or retrieve finder_session_id
        let finderSessionId = localStorage.getItem('finder_session_id');
        if (!finderSessionId) {
            finderSessionId = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
                const r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
                return v.toString(16);
            });
            localStorage.setItem('finder_session_id', finderSessionId);
        }

        // Open Modal
        btnMessageOwner.addEventListener('click', async () => {
            chatModal.classList.remove('hidden');
            chatInput.focus();
            
            // Show loading placeholder
            chatMessages.innerHTML = `
                <div class="text-center my-4" id="chat-loading">
                    <span class="text-xs text-slate-400 font-semibold">Connecting securely to owner...</span>
                </div>
            `;

            try {
                // 1. Check if active conversation exists
                const { data: convs, error: fetchErr } = await supabaseClient
                    .from('conversations')
                    .select('id, is_active')
                    .eq('tag_id', tagId)
                    .eq('finder_session_id', finderSessionId);

                if (fetchErr) throw fetchErr;

                activeConversation = convs ? convs.find(c => c.is_active) : null;

                // 2. If no active conversation, create one
                if (!activeConversation) {
                    const { data: newConv, error: createErr } = await supabaseClient
                        .from('conversations')
                        .insert({
                            tag_id: tagId,
                            finder_session_id: finderSessionId,
                            is_active: true
                        })
                        .select()
                        .single();

                    if (createErr) throw createErr;
                    activeConversation = newConv;
                }

                // 3. Fetch past messages
                const { data: pastMessages, error: msgErr } = await supabaseClient
                    .from('messages')
                    .select('*')
                    .eq('conversation_id', activeConversation.id)
                    .order('created_at', { ascending: true });

                if (msgErr) throw msgErr;

                // Clear loading status
                chatMessages.innerHTML = `
                    <div class="text-center my-2">
                        <span class="text-[10px] bg-slate-200/60 text-slate-500 font-bold px-3 py-1 rounded-full uppercase tracking-wider">Connection Secure</span>
                    </div>
                `;

                // Render existing messages
                if (pastMessages && pastMessages.length > 0) {
                    pastMessages.forEach(m => {
                        appendMessage(m.sender, m.content, m.id);
                    });
                } else {
                    // Initial Welcome message
                    appendMessage('owner', `Hello! Thank you so much for scanning the tag. Did you find my pet? Where are they now?`);
                }

                scrollToBottom();

                // 4. Initialize Realtime subscription
                if (realtimeSubscription) {
                    realtimeSubscription.unsubscribe();
                }

                realtimeSubscription = supabaseClient
                    .channel(`chat-room-${activeConversation.id}`)
                    .on('postgres_changes', {
                        event: 'INSERT',
                        schema: 'public',
                        table: 'messages',
                        filter: `conversation_id=eq.${activeConversation.id}`
                    }, payload => {
                        const newMsg = payload.new;
                        // Avoid double-rendering
                        if (!document.getElementById(`msg-${newMsg.id}`)) {
                            appendMessage(newMsg.sender, newMsg.content, newMsg.id);
                            scrollToBottom();
                        }
                    })
                    .subscribe();

            } catch (err) {
                console.error("Chat error:", err);
                chatMessages.innerHTML = `
                    <div class="text-center my-4 text-red-500 font-semibold text-sm">
                        Unable to establish connection. Please try again.
                    </div>
                `;
            }
        });

        // Close Modal
        btnCloseChat.addEventListener('click', () => {
            chatModal.classList.add('hidden');
            if (realtimeSubscription) {
                realtimeSubscription.unsubscribe();
                realtimeSubscription = null;
            }
        });

        // Send Message Handler
        const handleSendMessage = async () => {
            const text = chatInput.value.trim();
            if (text === '' || !activeConversation) return;

            chatInput.value = '';
            
            // Check if this is the first message (only default welcome exists)
            const isFirstUserMessage = chatMessages.querySelectorAll('[id^="msg-"]').length === 0;

            try {
                // Generate a client-side temporary message ID to append instantly
                const tempId = 'temp-' + Date.now();
                appendMessage('finder', text, tempId);
                scrollToBottom();

                // Insert into Supabase
                const { data, error } = await supabaseClient
                    .from('messages')
                    .insert({
                        conversation_id: activeConversation.id,
                        sender: 'finder',
                        content: text
                    })
                    .select()
                    .single();

                if (error) throw error;

                // Replace the temporary ID element with the real database message ID
                const tempEl = document.getElementById(`msg-${tempId}`);
                if (tempEl) {
                    tempEl.id = `msg-${data.id}`;
                }

                // If it is the first finder message, push notification to the owner's phone via notify-owner function
                if (isFirstUserMessage) {
                    notifyOwnerApi(tagId, null, null);
                }

            } catch (err) {
                console.error("Error sending message:", err);
                alert("Failed to send message. Please try again.");
            }
        };

        btnSendMessage.addEventListener('click', handleSendMessage);
        chatInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') {
                handleSendMessage();
            }
        });

        function appendMessage(sender, text, id) {
            const msgDiv = document.createElement('div');
            msgDiv.id = id ? `msg-${id}` : '';
            
            if (sender === 'finder') {
                msgDiv.className = "flex items-start gap-2.5 max-w-[85%] self-end flex-row-reverse";
                msgDiv.innerHTML = `
                    <div class="bg-indigo-600 rounded-2xl rounded-tr-none p-3 shadow-sm text-sm text-white leading-relaxed font-semibold">
                        <p>${text}</p>
                    </div>
                `;
            } else {
                msgDiv.className = "flex items-start gap-2.5 max-w-[85%]";
                msgDiv.innerHTML = `
                    <div class="w-8 h-8 rounded-full bg-gray-200 overflow-hidden flex-shrink-0">
                        <img src="${owner?.avatar_url || ''}" alt="Owner" class="owner-photo w-full h-full object-cover ${owner?.avatar_url ? '' : 'hidden'}">
                        <svg class="owner-no-photo w-full h-full text-gray-400 p-1.5 ${owner?.avatar_url ? 'hidden' : ''}" fill="currentColor" viewBox="0 0 24 24"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>
                    </div>
                    <div class="bg-white border border-gray-100 rounded-2xl rounded-tl-none p-3 shadow-sm text-sm text-slate-800 leading-relaxed font-medium">
                        <p>${text}</p>
                    </div>
                `;
            }
            chatMessages.appendChild(msgDiv);
        }

        function scrollToBottom() {
            chatMessages.scrollTop = chatMessages.scrollHeight;
        }
    }
});