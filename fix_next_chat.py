import re

with open('next-frontend/src/app/inbox/page.js', 'r') as f:
    content = f.read()

# 1. Add state for replyingTo
if "const [replyingTo, setReplyingTo]" not in content:
    content = content.replace("const [isTyping, setIsTyping] = useState(false);", "const [isTyping, setIsTyping] = useState(false);\n  const [replyingTo, setReplyingTo] = useState(null);")

# 2. Add Quick Replies array
if "const quickReplies =" not in content:
    content = content.replace("const isBlocked = iBlockedThem || theyBlockedMe;", "const isBlocked = iBlockedThem || theyBlockedMe;\n  const quickReplies = ['Hello! How can I help you?', 'Let me check the details.', 'Thanks for ordering!', 'I\\'ll deliver this soon.', 'Could you provide more info?'];")

# 3. Update sendMessage to include replyTo fields
old_send = """      await addDoc(collection(db, "conversations", activeChat.id, "messages"), {
        text: messageText,
        senderId: user.uid,
        senderName: dbUser?.name || "User",
        createdAt: serverTimestamp(),
        type: "text",
      });"""
new_send = """      const msgData = {
        text: messageText,
        senderId: user.uid,
        senderName: dbUser?.name || "User",
        createdAt: serverTimestamp(),
        type: "text",
      };
      if (replyingTo) {
        msgData.replyToId = replyingTo.id;
        msgData.replyToText = replyingTo.text;
        msgData.replyToSender = replyingTo.senderName;
      }
      await addDoc(collection(db, "conversations", activeChat.id, "messages"), msgData);
      setReplyingTo(null);"""
content = content.replace(old_send, new_send)

# 4. Add UI for Quick Replies and Reply Preview above input
old_input = """              {/* Message Input */}
              {isBlocked ? ("""
new_input = """              {/* Message Input */}
              {isBlocked ? ("""
if "{/* Quick Replies */}" not in content:
    qr_ui = """              {/* Quick Replies */}
              {(dbUser?.role === 'freelancer' || dbUser?.role === 'admin') && (
                <div className="px-4 pb-2 flex gap-2 overflow-x-auto no-scrollbar">
                  {quickReplies.map((qr, idx) => (
                    <button key={idx} onClick={() => { setNewMessage(qr); }} className="whitespace-nowrap px-3 py-1.5 bg-gray-100 dark:bg-gray-800 hover:bg-gray-200 dark:hover:bg-gray-700 text-xs font-semibold rounded-full text-gray-700 dark:text-gray-300 transition-colors">
                      {qr}
                    </button>
                  ))}
                </div>
              )}
              
              {/* Reply Preview */}
              {replyingTo && (
                <div className="mx-4 mb-2 p-3 bg-gray-100 dark:bg-gray-800 rounded-lg flex items-center justify-between border-l-4 border-[#00C6A2]">
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-bold text-[#00C6A2] mb-1">{replyingTo.senderName}</p>
                    <p className="text-xs text-gray-600 dark:text-gray-300 truncate">{replyingTo.text}</p>
                  </div>
                  <button onClick={() => setReplyingTo(null)} className="ml-4 text-gray-500 hover:text-gray-700 dark:hover:text-gray-300">
                    <UserX size={16} /> {/* Using UserX as close icon since X might not be imported */}
                  </button>
                </div>
              )}
"""
    content = content.replace("              {/* Message Input */}", qr_ui + "\n              {/* Message Input */}")

# 5. Render Reply UI in message bubble and add Reply button
old_bubble = """                        <div className={`max-w-[75%] rounded-2xl px-4 py-2.5 relative group ${isMe ? 'bg-[#00C6A2] text-white rounded-br-sm shadow-md' : 'bg-white dark:bg-gray-800 border border-gray-100 dark:border-white/10 rounded-bl-sm text-gray-800 dark:text-gray-200 shadow-sm'}`}>
                          <div className="text-[15px] leading-relaxed">{renderMessageText(msg.text)}</div>"""
new_bubble = """                        <div className={`max-w-[75%] rounded-2xl px-4 py-2.5 relative group ${isMe ? 'bg-[#00C6A2] text-white rounded-br-sm shadow-md' : 'bg-white dark:bg-gray-800 border border-gray-100 dark:border-white/10 rounded-bl-sm text-gray-800 dark:text-gray-200 shadow-sm'}`}>
                          {msg.replyToText && (
                            <div className={`mb-2 p-2 rounded text-xs border-l-4 ${isMe ? 'bg-white/20 border-white text-white' : 'bg-gray-100 dark:bg-gray-700 border-[#00C6A2] text-gray-800 dark:text-gray-200'}`}>
                              <p className="font-bold mb-0.5">{msg.replyToSender}</p>
                              <p className="truncate opacity-90">{msg.replyToText}</p>
                            </div>
                          )}
                          <div className="text-[15px] leading-relaxed">{renderMessageText(msg.text)}</div>
                          
                          {/* Reply Button on Hover */}
                          <button 
                            onClick={() => setReplyingTo(msg)}
                            className={`absolute top-1/2 -translate-y-1/2 opacity-0 group-hover:opacity-100 transition-opacity p-1.5 rounded-full bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-300 ${isMe ? '-left-10' : '-right-10'}`}
                            title="Reply"
                          >
                            <MessageSquare size={14} />
                          </button>"""
content = content.replace(old_bubble, new_bubble)

with open('next-frontend/src/app/inbox/page.js', 'w') as f:
    f.write(content)
print("Updated next-frontend chat features")
