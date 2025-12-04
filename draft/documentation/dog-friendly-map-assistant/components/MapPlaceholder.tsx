import React from 'react';
import { Place, Event, LatLng } from '../types';
import { LocationMarkerIcon, ArrowPathIcon } from './icons';

interface MapPlaceholderProps {
  places: Place[];
  events: Event[];
  center: LatLng | null;
  onPlaceClick: (place: Place) => void;
  onEventClick: (event: Event) => void;
  onSearchArea: (newCenter: LatLng) => void;
  showEvents: boolean;
}

const MapPlaceholder: React.FC<MapPlaceholderProps> = ({ places, events, center, onPlaceClick, onEventClick, onSearchArea, showEvents }) => {
    const allPoints = [...places.map(p => p.position), ...(showEvents ? events.map(e => e.position) : [])];
    
    if (allPoints.length === 0 && !center) {
        return (
            <div className="w-full h-full bg-gray-300 rounded-lg flex items-center justify-center">
                <p className="text-gray-600">Map will appear here.</p>
            </div>
        );
    }
    
    const lats = allPoints.map(p => p.lat);
    const lngs = allPoints.map(p => p.lng);
    
    const minLat = Math.min(...lats);
    const maxLat = Math.max(...lats);
    const minLng = Math.min(...lngs);
    const maxLng = Math.max(...lngs);
    
    const latRange = maxLat - minLat;
    const lngRange = maxLng - minLng;
    
    const normalizePosition = (pos: LatLng) => {
        // Add a small buffer to avoid points on the very edge
        const buffer = 0.05;
        // Check for zero range to prevent division by zero
        const top = latRange > 0.0001 ? (1 - (pos.lat - minLat) / latRange) * (1 - 2 * buffer) * 100 + buffer * 100 : 50;
        const left = lngRange > 0.0001 ? ((pos.lng - minLng) / lngRange) * (1 - 2 * buffer) * 100 + buffer * 100 : 50;
        return { top: `${top}%`, left: `${left}%` };
    };

    const handleSearchClick = () => {
        if (center) {
            // Simulate moving the map to a new random nearby location to fetch new data
            const newCenter = {
                lat: center.lat + (Math.random() - 0.5) * 0.02, // ~2km variation
                lng: center.lng + (Math.random() - 0.5) * 0.02,
            };
            onSearchArea(newCenter);
        }
    };

    return (
        <div className="w-full h-full bg-gray-200 rounded-lg relative overflow-hidden">
             <div className="absolute top-4 left-1/2 -translate-x-1/2 z-10">
                {center && (
                    <button 
                        onClick={handleSearchClick}
                        className="px-4 py-2 bg-white text-gray-800 text-sm font-semibold rounded-full shadow-lg hover:bg-gray-100 transition-colors flex items-center gap-2"
                    >
                        <ArrowPathIcon className="w-5 h-5" />
                        Search This Area
                    </button>
                )}
            </div>
            
            {allPoints.length === 0 && center && (
                 <div className="w-full h-full flex items-center justify-center">
                    <p className="text-gray-600">Searching for places...</p>
                </div>
            )}

            {places.map(place => {
                const { top, left } = normalizePosition(place.position);
                return (
                    <button
                        key={place.id}
                        onClick={() => onPlaceClick(place)}
                        className="absolute transform -translate-x-1/2 -translate-y-full"
                        style={{ top, left }}
                        title={place.name}
                    >
                        <LocationMarkerIcon className="w-6 h-6 text-indigo-600 hover:text-indigo-800 transition-colors drop-shadow" />
                    </button>
                );
            })}
            
            {showEvents && events.map(event => {
                const { top, left } = normalizePosition(event.position);
                return (
                    <button
                        key={event.id}
                        onClick={() => onEventClick(event)}
                        className="absolute transform -translate-x-1/2 -translate-y-1/2"
                        style={{ top, left }}
                        title={event.title}
                    >
                        <span className="block w-3 h-3 bg-pink-500 rounded-full ring-2 ring-white hover:ring-pink-700 transition-all"></span>
                    </button>
                );
            })}
        </div>
    );
};

export default MapPlaceholder;
