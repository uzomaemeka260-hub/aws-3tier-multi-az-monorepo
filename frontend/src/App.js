import React, { useState, useEffect } from 'react';

function App() {
    const [users, setUsers] = useState([]);
    const [username, setUsername] = useState('');
    const [address, setAddress] = useState('');

    const loadData = async () => {
        try {
            const res = await fetch('/api/users');
            const data = await res.json();
            setUsers(data);
        } catch (e) { console.error(e); }
    };

    const saveUser = async (e) => {
        e.preventDefault();
        try {
            await fetch('/api/users', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, address })
            });
            setUsername(''); setAddress(''); loadData();
        } catch (e) { console.error(e); }
    };

    useEffect(() => { loadData(); }, []);

    return (
        <div style={{ padding: '30px', fontFamily: 'sans-serif' }}>
            <h2>Database Roster Application (LocalStack Verification Mode)</h2>
            <form onSubmit={saveUser}>
                <input placeholder="Name" value={username} onChange={e => setUsername(e.target.value)} required /><br /><br />
                <input placeholder="Address" value={address} onChange={e => setAddress(e.target.value)} required /><br /><br />
                <button type="submit">Save to Local Database</button>
            </form>
            <h3>Saved Profiles:</h3>
            <ul>{users.map(u => <li key={u.id}>{u.username} - {u.address}</li>)}</ul>
        </div>
    );
}
export default App;
