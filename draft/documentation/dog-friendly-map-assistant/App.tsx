import React, { useState, useEffect, useMemo } from 'react';
import { Place, Event, Filters, LatLng, AiResponse } from './types';
import { fetchMockPlaces, fetchMockEvents } from './services/mockDataService';
import { askGeminiAboutPlaces } from './services/geminiService';
import { useGeolocation } from './hooks/useGeolocation';
import MapPlaceholder from './components/MapPlaceholder';
import BottomSheet from './components/BottomSheet';
import AiAssistant from './components/AiAssistant';
import { SparklesIcon, StarIcon } from './components/icons';

type SheetContent = 
  | { type: 'place'; data: Place }
  | { type: 'event'; data: Event }
  | { type: 'ai' };

const App: React.FC = () => {
  const { location, loading: geoLoading, error: geoError } = useGeolocation();
  const [places, setPlaces] = useState<Place[]>([]);
  const [events, setEvents] = useState<Event[]>([]);
  const [mapCenter, setMapCenter] = useState<LatLng | null>(null);
  
  const [filters, setFilters] = useState<Filters>({
    searchQuery: '',
    category: 'all',
    openNow: false,
    showEvents: true,
    amenities: [],
  });

  const [sheetContent, setSheetContent] = useState<SheetContent | null>(null);
  const [aiResponse, setAiResponse] = useState<AiResponse | null>(null);
  const [isAiLoading, setIsAiLoading] = useState(false);

  // Set the initial map center from geolocation
  useEffect(() => {
    if (location && !mapCenter) {
      setMapCenter(location);
    }
  }, [location]);

  // Fetch data whenever the map center changes
  useEffect(() => {
    if (mapCenter) {
      setPlaces([]);
      setEvents([]);
      fetchMockPlaces(mapCenter).then(setPlaces);
      fetchMockEvents(mapCenter).then(setEvents);
    }
  }, [mapCenter]);

  const filteredPlaces = useMemo(() => {
    return places.filter(place => 
      place.name.toLowerCase().includes(filters.searchQuery.toLowerCase()) &&
      (filters.category === 'all' || place.categories.includes(filters.category)) &&
      (!filters.openNow || place.openNow) &&
      (filters.amenities.every(amenity => place.amenities.includes(amenity)))
    );
  }, [places, filters]);

  const handleAiQuery = async (query: string) => {
    setIsAiLoading(true);
    setAiResponse(null);
    const response = await askGeminiAboutPlaces(query, mapCenter);
    setAiResponse(response);
    setIsAiLoading(false);
  };

  const getEventsForPlace = (placeId: string) => {
    return events.filter(event => event.placeId === placeId);
  }
  
  const handleToggleArrayFilter = (field: 'amenities', value: string) => {
    setFilters(f => {
      const currentValues = f[field];
      const newValues = currentValues.includes(value)
        ? currentValues.filter(item => item !== value)
        : [...currentValues, value];
      return { ...f, [field]: newValues };
    });
  };

  const handleSearchArea = (newCenter: LatLng) => {
    setMapCenter(newCenter);
  };

  const renderPlaceDetails = (place: Place) => {
    const placeEvents = getEventsForPlace(place.id);
    return (
        <div className="space-y-4">
            <div className="flex items-center gap-4 text-sm">
                <span className={`px-2 py-1 text-xs font-semibold rounded-full ${place.openNow ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
                    {place.openNow ? 'Open Now' : 'Closed'}
                </span>
                <div className="flex items-center gap-1 text-yellow-500">
                    <StarIcon className="w-5 h-5"/>
                    <span className="font-bold">{place.rating}</span>
                </div>
            </div>
            <p className="text-gray-600">Categories: {place.categories.join(', ')}</p>
            {place.amenities.length > 0 && (
                <div>
                    <h3 className="text-md font-semibold text-gray-800 mb-2">Amenities</h3>
                    <div className="flex flex-wrap gap-2">
                        {place.amenities.map(amenity => (
                            <span key={amenity} className="px-2 py-1 bg-gray-100 text-gray-800 text-xs font-medium rounded-full capitalize">{amenity}</span>
                        ))}
                    </div>
                </div>
            )}
            {placeEvents.length > 0 && (
                <div>
                    <h3 className="text-md font-semibold text-gray-800 mb-2">Upcoming Events</h3>
                    <ul className="space-y-2">
                        {placeEvents.map(event => (
                            <li key={event.id} className="p-2 bg-gray-50 rounded-md">
                                <p className="font-semibold text-gray-700">{event.title}</p>
                                <p className="text-sm text-gray-500">{event.startTime.toLocaleString()}</p>
                            </li>
                        ))}
                    </ul>
                </div>
            )}
        </div>
    );
  };
  
  const renderEventDetails = (event: Event) => (
    <div className="space-y-2">
        <p className="text-gray-600">{event.description}</p>
        <p className="text-sm text-gray-800"><strong>Starts:</strong> {event.startTime.toLocaleString()}</p>
        <p className="text-sm text-gray-800"><strong>Ends:</strong> {event.endTime.toLocaleString()}</p>
        <div className="flex flex-wrap gap-2 pt-2">
            {event.tags.map(tag => (
                <span key={tag} className="px-2 py-1 bg-indigo-100 text-indigo-800 text-xs font-medium rounded-full">{tag}</span>
            ))}
        </div>
    </div>
  );
  
  const FilterChip: React.FC<{
    label: string;
    onClick: () => void;
    isActive?: boolean;
  }> = ({ label, onClick, isActive }) => (
      <button
          onClick={onClick}
          className={`px-3 py-1 text-sm font-medium rounded-full transition-colors capitalize border ${
              isActive ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-700 hover:bg-gray-100'
          }`}
      >
          {label}
      </button>
  );

  return (
    <div className="h-screen w-screen flex flex-col p-2 md:p-4 bg-gray-50 font-sans">
      <header className="flex-shrink-0 mb-4">
        <h1 className="text-2xl md:text-3xl font-bold text-gray-800 text-center">Dog Friendly Map Assistant</h1>
        {geoError && <p className="text-center text-red-500 text-sm mt-1">{geoError}</p>}
      </header>

      <div className="flex-grow flex flex-col md:flex-row gap-4 min-h-0">
        <main className="w-full h-full min-h-[300px] md:min-h-0">
          {geoLoading ? (
            <div className="w-full h-full flex items-center justify-center bg-gray-200 rounded-lg">
                <p className="text-gray-600">Getting your location...</p>
            </div>
          ) : mapCenter ? (
            <MapPlaceholder 
              places={filteredPlaces} 
              events={events}
              center={mapCenter}
              onPlaceClick={(p) => setSheetContent({ type: 'place', data: p })}
              onEventClick={(e) => setSheetContent({ type: 'event', data: e })}
              onSearchArea={handleSearchArea}
              showEvents={filters.showEvents}
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center bg-gray-200 rounded-lg">
                <p className="text-gray-600 text-center p-4">Could not get your location. Please enable location services and refresh the page.</p>
            </div>
          )}
        </main>
        
        <aside className="flex-shrink-0 md:w-80 lg:w-96 flex flex-col gap-4">
          <div className="p-4 bg-white rounded-lg shadow">
              <input 
                type="text" 
                placeholder="Search places..."
                value={filters.searchQuery}
                onChange={(e) => setFilters(f => ({...f, searchQuery: e.target.value}))}
                className="w-full px-4 py-2 border rounded-full focus:outline-none focus:ring-2 focus:ring-indigo-500"
              />
          </div>
          <div className="p-4 bg-white rounded-lg shadow space-y-4">
              <h3 className="font-semibold text-gray-700">Filters</h3>
              <div className="flex flex-wrap gap-2">
                  <FilterChip label="All" onClick={() => setFilters(f => ({...f, category: 'all'}))} isActive={filters.category === 'all'} />
                  <FilterChip label="Cafes" onClick={() => setFilters(f => ({...f, category: 'cafe'}))} isActive={filters.category === 'cafe'} />
                  <FilterChip label="Parks" onClick={() => setFilters(f => ({...f, category: 'park'}))} isActive={filters.category === 'park'} />
                  <FilterChip label="Stores" onClick={() => setFilters(f => ({...f, category: 'store'}))} isActive={filters.category === 'store'} />
              </div>
              <div>
                  <h4 className="text-sm font-medium text-gray-700">Amenities</h4>
                  <div className="flex flex-wrap gap-2 mt-1">
                      {['dog water bowls', 'shaded areas'].map(amenity => (
                          <FilterChip 
                              key={amenity}
                              label={amenity}
                              isActive={filters.amenities.includes(amenity)}
                              onClick={() => handleToggleArrayFilter('amenities', amenity)}
                          />
                      ))}
                  </div>
              </div>
              <div className="flex items-center justify-between pt-2">
                <label className="text-sm text-gray-600">Show Events on Map</label>
                <button
                    onClick={() => setFilters(f => ({...f, showEvents: !f.showEvents}))}
                    className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${filters.showEvents ? 'bg-indigo-600' : 'bg-gray-200'}`}
                >
                    <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${filters.showEvents ? 'translate-x-6' : 'translate-x-1'}`}/>
                </button>
              </div>
          </div>
          <button 
            onClick={() => { setSheetContent({type: 'ai'}); if(!aiResponse) { handleAiQuery("Suggest some good dog friendly places nearby"); } }}
            className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-gradient-to-r from-purple-500 to-indigo-600 text-white font-bold rounded-lg shadow-md hover:shadow-lg transition-shadow"
            >
            <SparklesIcon className="w-6 h-6"/>
            Ask AI Assistant
          </button>
        </aside>
      </div>

      <BottomSheet
        isOpen={sheetContent !== null}
        onClose={() => setSheetContent(null)}
        title={
            sheetContent?.type === 'place' ? sheetContent.data.name :
            sheetContent?.type === 'event' ? sheetContent.data.title :
            'AI Map Assistant'
        }
      >
        {sheetContent?.type === 'place' && renderPlaceDetails(sheetContent.data)}
        {sheetContent?.type === 'event' && renderEventDetails(sheetContent.data)}
        {sheetContent?.type === 'ai' && <AiAssistant onQuery={handleAiQuery} aiResponse={aiResponse} isLoading={isAiLoading} />}
      </BottomSheet>
    </div>
  );
};

export default App;