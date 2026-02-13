export interface LatLng {
  lat: number;
  lng: number;
}

export interface Place {
  id: string;
  name: string;
  position: LatLng;
  categories: string[];
  rating: number;
  openNow: boolean;
  amenities: string[];
}

export interface Event {
  id: string;
  placeId: string | null;
  position: LatLng;
  title: string;
  description: string;
  startTime: Date;
  endTime: Date;
  tags: string[];
}

export interface Filters {
  searchQuery: string;
  category: 'all' | 'cafe' | 'park' | 'store';
  openNow: boolean;
  showEvents: boolean;
  amenities: string[];
}

export interface GroundingChunk {
  maps: {
    uri: string;
    title: string;
  }
}

export interface AiResponse {
  text: string;
  sources: GroundingChunk[];
}