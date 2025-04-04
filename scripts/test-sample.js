// Example file with a few bugs for testing claude-suggest
function calculateTotal(items) {
    let total = 0;
    for (let i = 0; i < items.length; i++) {
        // Bug 1: No null check before accessing properties
        total += items[i].price * items[i].quantity;
    }
    return total;
}

// Bug 2: Potential division by zero
function calculateAverage(values) {
    const sum = values.reduce((acc, val) => acc + val, 0);
    return sum / values.length;
}

// Bug 3: No error handling
async function fetchUserData(userId) {
    const response = await fetch(`/api/users/${userId}`);
    const data = await response.json();
    return data;
}

module.exports = {
    calculateTotal,
    calculateAverage,
    fetchUserData
};