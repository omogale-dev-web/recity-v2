"use client";
import {useEffect} from 'react';
export default function Pwa(){useEffect(()=>{if('serviceWorker' in navigator&&!['localhost','127.0.0.1'].includes(location.hostname)){navigator.serviceWorker.register('/sw.js').catch(()=>{})}},[]);return null}
