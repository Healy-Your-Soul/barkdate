import { Place, Event, LatLng } from '../types';

const generateRandomPosition = (center: LatLng, radius: number): LatLng => {
  const y0 = center.lat;
  const x0 = center.lng;
  const rd = radius / 111300; // about 111300 meters in one degree

  const u = Math.random();
  const v = Math.random();

  const w = rd * Math.sqrt(u);
  const t = 2 * Math.PI * v;
  const x = w * Math.cos(t);
  const y = w * Math.sin(t);

  return {
    lat: y + y0,
    lng: x + x0,
  };
};


export const fetchMockPlaces = async (center: LatLng): Promise<Place[]> => {
  const places: Omit<Place, 'position'>[] = [
    { id: 'p1', name: 'The Barking Bean Cafe', categories: ['cafe'], rating: 4.8, openNow: true, amenities: ['dog water bowls', 'shaded areas'] },
    { id: 'p2', name: 'Paws & Play Dog Park', categories: ['park'], rating: 4.9, openNow: true, amenities: ['shaded areas'] },
    { id: 'p3', name: 'Canine Corner Store', categories: ['store'], rating: 4.5, openNow: false, amenities: [] },
    { id: 'p4', name: 'The Muddy Paw', categories: ['cafe', 'store'], rating: 4.3, openNow: true, amenities: ['dog water bowls'] },
    { id: 'p5', name: 'Central Bark', categories: ['park'], rating: 4.7, openNow: true, amenities: ['dog water bowls', 'shaded areas'] },
    { id: 'p6', name: 'Java Hounds', categories: ['cafe'], rating: 4.6, openNow: true, amenities: ['dog water bowls'] },
    { id: 'p7', name: 'Fetch! Pet Supplies', categories: ['store'], rating: 4.8, openNow: true, amenities: [] },
    { id: 'p8', name: 'Greenwood Dog Run', categories: ['park'], rating: 4.4, openNow: true, amenities: ['shaded areas'] },
    { id: 'p9', 'name': 'The Daily Grind', categories: ['cafe'], rating: 4.2, openNow: false, amenities: [] },
    { id: 'p10', name: 'Grand Lake Dog Park', categories: ['park'], rating: 5.0, openNow: true, amenities: ['dog water bowls', 'shaded areas'] },
  ];
  return places.map(p => ({ ...p, position: generateRandomPosition(center, 2000) }));
};

export const fetchMockEvents = async (center: LatLng): Promise<Event[]> => {
    const now = new Date();
    const events = [
    { id: 'e1', placeId: 'p2', title: 'Yappy Hour Meetup', description: 'A social hour for dogs and their owners.', startTime: new Date(now.getTime() + 2 * 60 * 60 * 1000), endTime: new Date(now.getTime() + 4 * 60 * 60 * 1000), tags: ['meetup'] },
    { id: 'e2', placeId: 'p5', title: 'Agility Training Intro', description: 'Learn the basics of dog agility.', startTime: new Date(now.getTime() + 24 * 60 * 60 * 1000), endTime: new Date(now.getTime() + 26 * 60 * 60 * 1000), tags: ['training'] },
    { id: 'e3', placeId: null, title: 'Rescue Adoption Day', description: 'Meet adoptable dogs from local shelters.', startTime: new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000), endTime: new Date(now.getTime() + 2 * 24 * 60 * 60 * 1000 + 4 * 60 * 60 * 1000), tags: ['adoption'] },
    { id: 'e4', placeId: 'p1', title: 'Pups & Pastries', description: 'Enjoy a coffee and a treat with your furry friend.', startTime: new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000), endTime: new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000 + 2 * 60 * 60 * 1000), tags: ['meetup'] },
  ];
  return events.map(e => ({ ...e, position: e.placeId ? generateRandomPosition(center, 200) : generateRandomPosition(center, 3000) }));
};