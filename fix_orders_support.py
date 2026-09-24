import re

with open('next-frontend/src/app/profile/orders/page.js', 'r') as f:
    content = f.read()

# 1. Add Support Modal State
old_state = """  const [comment, setComment] = useState("");
  const [submittingReview, setSubmittingReview] = useState(false);"""
new_state = """  const [comment, setComment] = useState("");
  const [submittingReview, setSubmittingReview] = useState(false);
  
  // Support Modal State
  const [supportOrder, setSupportOrder] = useState(null);
  const [supportMessage, setSupportMessage] = useState("");
  const [submittingSupport, setSubmittingSupport] = useState(false);"""
content = content.replace(old_state, new_state)

# 2. Add submitSupport function
support_func = """  const submitSupport = async () => {
    if (!supportMessage.trim()) return;
    setSubmittingSupport(true);
    try {
      await addDoc(collection(db, "support_tickets"), {
        title: `Support Ticket: Order ${supportOrder.id}`,
        description: supportMessage,
        reportedBy: user.uid,
        targetId: supportOrder.freelancerId,
        orderId: supportOrder.id,
        status: "open",
        createdAt: serverTimestamp(),
      });
      setSupportOrder(null);
      setSupportMessage("");
      alert("Support ticket submitted successfully.");
    } catch (e) {
      console.error(e);
      alert("Error submitting ticket.");
    } finally {
      setSubmittingSupport(false);
    }
  };

  """
if "const submitSupport =" not in content:
    content = content.replace("  const submitReview = async () => {", support_func + "const submitReview = async () => {")

# 3. Add Contact Support button to UI
old_btn = """                  <div className="flex gap-2">
                    <ContactUserButton 
                      freelancerId={order.freelancerId} 
                      className="px-4 py-2 border border-gray-300 dark:border-white/10 rounded-lg text-sm font-semibold hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
                    />"""
new_btn = """                  <div className="flex gap-2">
                    <button 
                      onClick={() => setSupportOrder(order)}
                      className="px-4 py-2 border border-red-300 text-red-600 dark:border-red-500/30 dark:text-red-400 rounded-lg text-sm font-semibold hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
                    >
                      Support
                    </button>
                    <ContactUserButton 
                      freelancerId={order.freelancerId} 
                      className="px-4 py-2 border border-gray-300 dark:border-white/10 rounded-lg text-sm font-semibold hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
                    />"""
content = content.replace(old_btn, new_btn)

# 4. Add Support Modal UI
modal_ui = """      {/* Support Modal */}
      {supportOrder && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
          <div className="bg-white dark:bg-gray-900 w-full max-w-md rounded-2xl p-6 shadow-2xl">
            <h3 className="text-xl font-bold mb-4 dark:text-white">Contact Support</h3>
            <p className="text-sm text-gray-500 mb-4">Please describe your issue regarding Order #{supportOrder.id.slice(-6)}.</p>
            <textarea 
              value={supportMessage}
              onChange={(e) => setSupportMessage(e.target.value)}
              className="w-full border border-gray-300 dark:border-white/10 rounded-xl p-3 h-28 focus:ring-2 focus:ring-[#00C6A2] outline-none dark:bg-gray-800 dark:text-white mb-4"
              placeholder="Describe your issue here..."
            ></textarea>
            <div className="flex gap-3">
              <button 
                onClick={() => setSupportOrder(null)} 
                className="flex-1 px-4 py-2 bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200 rounded-xl font-bold"
              >
                Cancel
              </button>
              <button 
                onClick={submitSupport} 
                disabled={submittingSupport || !supportMessage.trim()}
                className="flex-1 px-4 py-2 bg-[#00C6A2] text-white rounded-xl font-bold disabled:opacity-50"
              >
                {submittingSupport ? "Submitting..." : "Submit Ticket"}
              </button>
            </div>
          </div>
        </div>
      )}
"""
if "{/* Support Modal */}" not in content:
    content = content.replace("      {/* Review Modal */}", modal_ui + "\n      {/* Review Modal */}")

with open('next-frontend/src/app/profile/orders/page.js', 'w') as f:
    f.write(content)
print("Updated orders page with support")
