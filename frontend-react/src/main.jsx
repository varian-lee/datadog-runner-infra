import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.jsx';
import { initRUM } from './lib/rum';
import 'flowbite/dist/flowbite.min.css';

initRUM();
createRoot(document.getElementById('root')).render(<App />);
